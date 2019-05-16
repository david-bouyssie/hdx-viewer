#!C:/Perl64/bin/perl.exe -w

use strict;
use 5.20.0;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Slurp qw/read_file write_file/;
use POSIX;
use Try::Tiny;

#my $dirname = dirname(__FILE__);

use Mojolicious::Lite -signatures;

#plugin 'DefaultHelpers';

$ENV{MOJO_APP_LOADER} = 1;

### For PAR:Packer compat see https://gist.github.com/dex4er/22d5195a64e3058bc8a0
# Explicit use as a helper for PAR
use Mojolicious::Plugin::DefaultHelpers;
use Mojolicious::Plugin::EPLRenderer;
use Mojolicious::Plugin::EPRenderer;
use Mojolicious::Plugin::HeaderCondition;
use Mojolicious::Plugin::TagHelpers;

use Mojolicious::Commands;

@{app->static->paths} = (dirname($0).'\public');
#push @{app->static->paths}, dirname($0).'\public';

say "HDX-Viewer will load static files from: " .join("\n",@{app->static->paths});

my $hde_heatmap_colors_map = parse_hdexaminer_colors( [read_file("./conf/hdexaminer_heatmap_colors.txt")] );
my $hde_diff_heatmap_colors_map = parse_hdexaminer_colors( [read_file("./conf/hdexaminer_diff_heatmap_colors.txt")] );

my $UPLOAD_DIR = "./public/uploads/";
my $last_job_number = 0;

# Render template "index.html.ep" from the DATA section
get '/' => sub ($c) {
  $c->render(template => 'index');
};

# Multipart upload handler
post '/pdb_upload' => sub {
  my $c = shift;

  # Check file size
  return $c->render(json => {error => "One of the files is too big"}, status => 200) if $c->req->is_limit_exceeded;
  
  $last_job_number += 1;
  
  try {
  
    my $uid_as_str = _generate_job_uid($last_job_number);
    my $job_dir = $UPLOAD_DIR . "/job_$uid_as_str";
    mkdir($job_dir);
    
    my $cur_date = strftime "%Y-%m-%d %H:%M:%S", localtime time;
    my $user = $c->whois;
    say "Starting new job session in directory '$job_dir' for user '$user'";
    
    open(LOGFILE, '>>', "$UPLOAD_DIR/connections.log") or die $!;
    say LOGFILE "New connection of '$user' at $cur_date";
    close LOGFILE;
    
    my $job_input_dir = "$job_dir/input";
    mkdir("$job_input_dir");
    
    my @files = @{$c->req->uploads('file')};
    return $c->render(json => {error => "Can't upload/process more than one PDB file at a time"}, status => 200) if scalar(@files) > 1;
    
    my( $fasta_file, $chains );
    for my $file (@files) {
      my $size = $file->size;
      my $name = $file->filename;
      if (not $name =~ /.+\.pdb/) { return $c->render(json => {error => "Invalid input: file must be in PDB format"} ); }
      
      my $uploaded_file_location = "$job_input_dir/" . $file->filename;
      say "Uploaded PDB file location: $uploaded_file_location";
      
      $file->move_to($uploaded_file_location);
      
      ($fasta_file, $chains) = pdb2fasta($job_dir, $uploaded_file_location);
    }
    
    $c->render(json => {job_id => $uid_as_str, detected_chains => $chains} );
    
  } catch {
    warn "caught error: $_"; # not $@
    $c->render(json => {error => "PDB files upload failed\n". _split_error_msg($_)} );
  };
  
};

# Multipart upload handler
post '/pml_upload' => sub {
  my $c = shift;

  # Check file size
  return $c->render(json => {error => "One of the files is too big"}, status => 200) if $c->req->is_limit_exceeded;
  
  my $job_id = $c->req->param('job_id');
  my $chains = $c->req->param('chains');
  
  ### Check inputs
  return $c->render(json => {error => "Can't continue since no PDB files were uploaded"}, status => 200) unless $job_id;
  return $c->render(json => {error => "Invalid characters in provided chains '$chains'"}, status => 200) unless $chains =~ /^[a-zA-Z0-9]+$/;
  
  try {
    my $job_dir = $UPLOAD_DIR . "/job_$job_id";
    my $job_input_dir = "$job_dir/input";
    my $job_chains_input_dir = "$job_dir/input/$chains";
    mkdir($job_chains_input_dir);
    
    for my $file (@{$c->req->uploads('files')}) {
      my $size = $file->size;
      my $name = $file->filename;
      if (not $name =~ /.+\.pml/) { $c->render(json => {error => "Invalid input: file must be in PML format"} ); }
      
      my $uploaded_file_location = "$job_chains_input_dir/" . $file->filename;
      say "Uploaded PML file location: $uploaded_file_location";
      
      $file->move_to($uploaded_file_location);
    }
    
    $c->render(json => {job_id => $job_id, chains => $chains } );
    
  } catch {
    warn "caught error: $_"; # not $@
    $c->render(json => {error => "PML files upload failed\n". _split_error_msg($_)} );
  };
  
};

# Multipart upload handler
get '/process_files' => sub {
  my $c = shift;
  
  my $job_id = $c->req->param('job_id');
  my $chains = $c->req->param('chains');
  
  ### Check inputs
  return $c->render(json => {error => "Can't continue since no input files were uploaded"}, status => 200) unless $job_id;
  return $c->render(json => {error => "Invalid characters in provided chains '$chains'"}, status => 200) unless $chains =~ /^[a-zA-Z0-9]+$/;
  
  my $job_dir = $UPLOAD_DIR . "/job_$job_id";
  my $job_input_dir = "$job_dir/input";
  my $job_chains_input_dir = "$job_dir/input/$chains";
  my $temp_dir = "$job_dir/temp";
  
  my @pdb_files = <$job_input_dir/*.pdb>;
  say "Found ".scalar(@pdb_files). " PDB files in current job directory ($job_dir)";
  my $pdb_file_path = shift(@pdb_files);
  
  my @fasta_files = <$job_dir/*.fasta>;
  say "Found ".scalar(@fasta_files). " FASTA files in current job directory ($job_dir)";
  my $fasta_file = shift(@fasta_files);
  
  my @pml_file_paths = <$job_chains_input_dir/*.pml>;
  say "Found ".scalar(@pml_file_paths). " PML files in current chains directory ($job_chains_input_dir)";
  
  my $pml_files_count = scalar(@pml_file_paths);
  if ($pdb_file_path && $pml_files_count) {
  
    ### Create/backup merge PML file
    my($pdb_name,$pdb_dir,$pdb_ext) = fileparse($pdb_file_path,'.pdb');
    my $merged_pml_file_path = prepare_merged_pml_file($temp_dir, $pdb_name);
    my $merged_pml_file_backup_path = $merged_pml_file_path. '.bak';
    
    try {
      if (-f $merged_pml_file_path) {
        copy($merged_pml_file_path,$merged_pml_file_backup_path) or die "Merged PML backup failed: $!";
      }
      
      my $is_hdexaminer_pml = is_hdexaminer_pml($pml_file_paths[0]);
      
      if ($is_hdexaminer_pml) {
        hdexaminer2dynamx(\@pml_file_paths, $chains, $merged_pml_file_path, $temp_dir);
      }
      else {
        #$merged_pml_file_path = $pml_files_count == 1 ? $pml_file_paths[0] : merge_pml_files(\@pml_file_paths, $merged_pml_file_path);
        merge_pml_files(\@pml_file_paths, $merged_pml_file_path);
      }
      
      my ($output_files, $bfactor_mapping) = pml2pdb($job_dir, $pdb_file_path, $merged_pml_file_path);
      
      ### Remove backup
      unlink $merged_pml_file_backup_path if -f $merged_pml_file_backup_path;
      
      $c->render(json => {pdb_files => $output_files, fasta_file => $fasta_file, bfactor_mapping => $bfactor_mapping} );
    } catch {
      warn "caught error: $_"; # not $@
      
      say "Removing uploaded and generated PML files...";
      for my $file (@pml_file_paths, $merged_pml_file_path) {
        unlink $file if -f $file;
      }
      
      say "Restoring previous merged PML file...";
      if (-f $merged_pml_file_backup_path) {
        copy($merged_pml_file_backup_path,$merged_pml_file_path) or die "Merged PML restore failed: $!";
      }
      
      $c->render(json => {error => "Data loading failed\n". _split_error_msg($_) } );
    };
   
  } else {
    $c->render(json => {error => "Invalid input: missing PDB or PML input files"} );
  }
};

sub _split_error_msg($error) {
  my @parts = split(' at ', $error);
  return scalar(@parts) ? $parts[0] : '';
}

sub _generate_job_uid($job_number) {
  ### See: https://stackoverflow.com/questions/30731917/generate-a-unique-id-in-perl
  my $random_id = join '', map int rand 10, 1..6 ;
  my $uid_as_str = join('-',time,$job_number,$random_id); #Data::GUID->new->as_string;
  return $uid_as_str;
}

get '/test' => sub ($c) {
  say "hello";
  $c->render(text => 'I ♥ Mojolicious!');
};

get '/download_results' => sub ($c) {
  
  #my $files = $c->req->json;
  my $fasta_file = $c->param('fasta_file');
  my $pml_format = $c->param('pml_format');
  my @pdb_files = @{$c->every_param('pdb_files[]')};
  
  if (not $fasta_file =~ /^\.\/public/) {
    #say "invalid fasta_file file location";
    return $c->reply->exception("invalid fasta_file file location");
  }
  
  my( $job_dir, $job_suffix);
  if ($fasta_file =~ /^\.\/public\/demo/ ) {
    $job_dir = './public/demo';
    $job_suffix = lc($pml_format) .'-demo-dataset';
  } else {
    $job_dir = dirname($fasta_file);
    $job_suffix = basename($job_dir);
    
    #say "fasta_file: ". $fasta_file;
  }
  
  my $zip_file_name = "./public/downloads/hdx-viewer-$job_suffix.zip";
  #say "exists: ". -f $zip_file_name;
  
  ### Return cache if exists
  return $c->render(text => $zip_file_name) if -f $zip_file_name;
  
  my $zip = Archive::Zip->new();
  
  ### Add input files
  $zip->addDirectory("input");
  my @input_files = <$job_dir/input/*.*>;
  foreach my $input_file (@input_files) {
    $zip->addFile( $input_file, 'input/' . basename($input_file) );
  }
  
  ### Add output files
  #my $file_member = $zip->addFile( 'xyz.pl', 'AnotherName.pl' );
  $zip->addFile( $fasta_file, basename($fasta_file) );
  $zip->addFile( $_ , basename($_) ) foreach @pdb_files;
  
  ### Save the Zip file
  if ( $zip->writeToFileNamed($zip_file_name) != AZ_OK ) {
    say "can't create ZIP archive '$zip_file_name'";
  }
  
  $c->render(text => $zip_file_name);
};

# A helper to identify visitors
helper whois => sub {
  my $c     = shift;
  my $agent = $c->req->headers->user_agent || 'Anonymous';
  my $ip    = $c->tx->remote_address;
  return "$agent ($ip)";
};

under sub {
  my $c = shift;
  #say "test globals";
  $c->res->headers->access_control_allow_origin('*');
  return 1;
};

app->hook(after_dispatch => sub {
    my $tx = shift;
    #say "test after_dispatch";
    $tx->res->headers->access_control_allow_origin('*');
});

# get '/public/#file' => sub {
#   my $c = shift;
#   say "origin=".$c->res->headers->access_control_allow_origin;

#   $c->res->headers->access_control_allow_origin('*');
#   my $file = $c->stash('file');

#   say -f $file;
#   say -f "public/$file";
#   #$c->res->headers->content_disposition("attachment; filename=$file;");
#   #$c->reply->static("$file");

#   if (my $asset = $c->app->static->file('public/$file')) {
#     $c->res->headers->content_type('text/plain');
#     $c->reply->asset($asset);
#   } else {
#     #$c->render(text => 'no file');
#     $c->reply->static("./public/$file");
#   }
# };

# WebSocket service used by the template to extract the title from a web site
websocket '/title' => sub ($c) {
  $c->on(message => sub ($c, $msg) {
    my $title = $c->ua->get($msg)->result->dom->at('title')->text;
    $c->send($title);
  });
};

### START APP AND DAEMON ###
if (app->mode eq 'hdx-viewer-dev') { app->start; }
else {
  app->start;
  
  my $daemon = Mojo::Server::Daemon->new(app => app, listen => ['http://*:8080']);
  $daemon->start;
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


sub is_hdexaminer_pml($pml_path) {
  my $pml_as_str = read_file($pml_path);
  return ($pml_as_str =~ /set_color/);
}

sub hdexaminer2dynamx($pml_paths, $chains_as_str, $merged_pml_file, $temp_dir) {
  
  my (@converted_pml_paths, @time_points_in_secs);
  for my $pml_path (@$pml_paths) {
    my $pml_as_str = read_file($pml_path);
    my @pml_lines = split("\n", $pml_as_str);
    
    ### FIXME: check the two palettes and die if none of them matches
    my $is_hde_palette = check_hdexaminer_colors(\@pml_lines, $hde_heatmap_colors_map);
    my $is_hde_diff_palette = check_hdexaminer_colors(\@pml_lines, $hde_diff_heatmap_colors_map);
    die "Can't use provided PML files: the heatmap colors must be based on HDExaminer defaults" if (!$is_hde_palette && !$is_hde_diff_palette);
    
    my $pml_name = basename($pml_path);
    my ($pml_prefix, $hdx_time, $dmx_unit, $pml_suffix) = ($pml_name,0,'sec', '');
    if ($pml_name =~ /(.+)_(\d+)([smh])(.*)\.pml/) {
      $pml_prefix = $1;
      $hdx_time = $2;
      my $hde_unit = $3;
      $pml_suffix = $4 || '';

      if ($hde_unit eq 's') {
        push(@time_points_in_secs, $hdx_time);
      }
      if ($hde_unit eq 'm') {
        push(@time_points_in_secs, $hdx_time * 60);
        $dmx_unit = 'min';
      }
      elsif ($hde_unit eq 'h') {
        push(@time_points_in_secs, $hdx_time * 3600);
        $dmx_unit = 'hour';  ### FIXME: check this
      }
    }
    
    my $new_pml_file_path = "$temp_dir/$pml_name";
    open(NEW_PML, '>', $new_pml_file_path) or die $!;
    
    for my $line (@pml_lines) {
      if ($line =~ /color deutColor(\d+)x(\d),resi (\d+)-(\d+)/) { # set_color deutColor(\d+x\d)=(\[.+\])/) {
        my $color_major_num = $1;
        my $color_minor_num = $2;
        my $min_res_num = $3;
        my $max_res_num = $4;
        
        my $b_factor = $is_hde_palette ? "$1$2" / 100 : 2 * ( ("$1$2" / 100) - 0.6);
        
        for my $res_num ($min_res_num .. $max_res_num) {
          #say NEW_PML "alter /$pml_prefix//$chains_as_str/$res_num, properties[\"$pdb_name $hdx_time $dmx_unit ($pml_prefix$pml_suffix)\"] = $b_factor";
          my $properies_str = "$hdx_time $dmx_unit ($pml_prefix$pml_suffix)";
          $properies_str =~ s/ /_/g;
          say NEW_PML "alter /$pml_prefix//$chains_as_str/$res_num, properties[\"$properies_str\"] = $b_factor";
        }
      }
    }
    
    close NEW_PML;
    
    push(@converted_pml_paths, $new_pml_file_path);
  }

  ### Sort generated PMLs by time
  my @sorted_time_points_idx = sort { $time_points_in_secs[$a] <=> $time_points_in_secs[$b] } 0 .. $#time_points_in_secs;
  my @sorted_converted_pml_paths = @converted_pml_paths[@sorted_time_points_idx];

  merge_pml_files(\@sorted_converted_pml_paths, $merged_pml_file);
}

sub check_hdexaminer_colors($pml_as_str, $ref_color_map) {
  my $input_file_palette = parse_hdexaminer_colors($pml_as_str);
  
  while (my($idx,$color) = each(%$input_file_palette)) {
    my $ref_color = $ref_color_map->{$idx};
    return 0 if $ref_color ne $color;
  }

  return 1;
}

sub parse_hdexaminer_colors($colors_lines) {
  
  my %rvb_by_idx;
  for my $line (@$colors_lines) {
    if ($line =~ /set_color deutColor(\d+x\d)=(\[.+\])/) {
      $rvb_by_idx{$1} = $2;
    }
  }
  
  return \%rvb_by_idx;
}

sub prepare_merged_pml_file($temp_dir, $pdb_name) {
  mkdir $temp_dir;
  my $merged_pml_file = "$temp_dir/$pdb_name.pml";
}

sub merge_pml_files($pml_paths, $merged_pml_file) {  
  my @pml_files_to_merge = -f $merged_pml_file ? ($merged_pml_file, @$pml_paths) : @$pml_paths;
  my $merge_str =  join( '', map { read_file($_) } @pml_files_to_merge);
  write_file($merged_pml_file, $merge_str);
}

### Source: https://github.com/kad-ecoli/pdb2fasta/blob/master/pdb2fasta.pl
### See also: http://cupnet.net/pdb2fasta/
sub pml2pdb($job_dir, $pdb_path, $pml_path) {

  my($pdb_name,$pdb_dir,$pdb_ext) = fileparse($pdb_path,'.pdb');
  my($pml_name,$pml_dir,$pml_ext) = fileparse($pml_path,'.pml');
  $pdb_dir =~ s/\/$//;
  #say "hello jean";

  #my $a = 1;
  #my @tab = (1,2,3);
  #my %dict = ("jean" => 23, "david" => 35);

  my $start = time;

  ### Lire le fichier PML pour récupérer les facteurs B
  my %b_factor_list_by_res = ();
  my %target_list = ();
  my @sorted_time_points;

  open(PML_FILE,"<",$pml_path) or die $!;

  while (my $line = <PML_FILE>) {
    
    if ($line =~ /^$/ ) {next;}
    #elsif ($line =~ /alter \/\w+\/\/(\w+)\/(\d+), properties\[".*?(\d+\s\w+)"\] = ([-]?\d+[\.,]?\d*)/) {
    elsif ($line =~ /alter \/\w+\/\/(\w*)\/([-]?\d+).*, properties\["(.+)"\] = (.+)/) {
      my $chains = $1;
      die "Invalid PML entry, missing chain information in line: $line" if length($chains) == 0;
      
      my $residue_pos = $2;
      my $time_point_str = $3;
      my $b_factor = $4;
      $b_factor =~ s/,/\./;
      $b_factor += 0;
      
      #say "residue_pos $residue_pos b_factor = $b_factor";
      
      my $time_point;
      if ($time_point_str =~ /.*\s(\d+\s\w+)/) {
        $time_point = $1;
        $time_point =~ s/\s/_/g;
      } else {
        $time_point = $time_point_str
      }

      #say join("\t",$chain,$residue_pos,$time_point, $b_factor);
      my @chain_list = split('', $chains);
      
      foreach my $chain_name (@chain_list) {
        $b_factor_list_by_res{ $chain_name.'%'.$residue_pos }{$time_point} = $b_factor;
      }

      push(@sorted_time_points,$time_point) if !$target_list{$time_point};
      
      $target_list{$time_point} = 1;
      
    } else {
      die "Can't parse line: $line";
    }
  }

  close PML_FILE;
  
  #say Dumper \@sorted_time_points;

  ### On ouvre en écriture autant de fichier que de time points
  my @output_files;
  my %pdb_name_by_time_point = ();

  my %file_by_time_point = map {
    my $time_point = $_;
    
    my $new_pdb_name = $pdb_name."_$time_point.pdb";
    $pdb_name_by_time_point{$time_point} = $new_pdb_name;

    my $pdb_path = $job_dir.'/'.$new_pdb_name;
    push(@output_files, $pdb_path);
    
    my $fh;
    open($fh,">",$pdb_path) or die $!;
    
    ( $time_point, $fh );
  } @sorted_time_points;
  #die Dumper \%file_by_time_point;

  #say Dumper \%b_factor_by_res;
  #say Dumper \@time_point_list;

  my %pdb_chain_idx_by_name;

  ### Lire le fichier PDB pour blablabla les facteurs B
  open(PDB_FILE,"<",$pdb_path) or die $!;

  while (my $line = <PDB_FILE>) {

    # Exemple: ATOM  23404  CA  LEU N 237     -87.407  -0.364 160.421  1.00 78.66           C
    # Exemple: ATOM    914  N   LEU A 115    -104.983  71.146  72.849  1.00  0.01           N
    if ($line =~ /ATOM\s+\d+\s+\w+\s+\w+\s+(\w)\s+(-*\d+)/ || $line =~ /HETATM\s+\d+\s+\w+\s+\w+\s+(\w)\s+(-*\d+)/) {
    
      #say "found atom line";

      ### Récupère la correspondance time_point -> b_factor
      my $chain = $1;
      my $res_pos = $2;
      my $residue = $chain.'%'.$res_pos;
      my $b_factor_by_time_point = $b_factor_list_by_res{ $residue } || {};
      $pdb_chain_idx_by_name{$chain} = -1;
      
      ### Pour chaque time point du fichier PML
      foreach my $time_point (@sorted_time_points) {
      
        ### Récupère le B factor pour le time point considéré
        my $obs_bfactor = $b_factor_by_time_point->{ "$time_point" };
        my $b_factor = defined $obs_bfactor ? $obs_bfactor : -1;
        my $b_factor_len = length("$b_factor");
        
        #say "found bfactor";
        
        ### Substitue le B factor dans la ligne provenant du fichier PDB
        #print $line;
        if ($line =~ /(ATOM\s+\d+\s+\w+\s+\w+\s+\w\s+-*\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2})(\s*)(\S+)(\s+)([A-Z]\s*)/ ||
            $line =~ /(HETATM\s+\d+\s+\w+\s+\w+\s+\w\s+-*\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2})(\s*)(\S+)(\s+)([A-Z]\s*)/
          ) {
          #say "found old bfactor";
          
          my $before_b_factor = $1;
          my $before_b_factor_space = $2;
          my $old_b_factor = $3;
          my $space_after_b_factor = $4;
          my $after_b_factor = $5;
          
          my $before_b_factor_space_len = length($before_b_factor_space);
          my $old_b_factor_len = length($old_b_factor);
          my $space_len = length($space_after_b_factor);
          
          my $new_space_len = ($before_b_factor_space_len - 1 ) + ($old_b_factor_len + $space_len) - $b_factor_len;
          my $new_space_after_b_factor = ' ' x $new_space_len;
          
          $line = "$before_b_factor $b_factor$new_space_after_b_factor$after_b_factor";               
        }
        
        # if ($line =~ /(ATOM\s+\d+\s+\w+\s+\w+\s+[A-Z]\s+\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2}\s*)(\S+)(\s+)([A-Z]\s*)/ ||
            # $line =~ /(HETATM\s+\d+\s+\w+\s+\w+\s+[A-Z]\s+\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2}\s*)(\S+)(\s+)([A-Z]\s*)/
          # ) {
          # my $before_b_factor = $1;
          # my $old_b_factor = $2;
          # my $space_after_b_factor = $3;
          # my $after_b_factor = $4;
          # my $old_b_factor_len = length($old_b_factor);
          # my $space_len = length($space_after_b_factor);
          
          # my $new_space_len = ($old_b_factor_len + $space_len) - $b_factor_len;
          # my $new_space_after_b_factor = ' ' x $new_space_len;
          
          # $line = "$before_b_factor$b_factor$new_space_after_b_factor$after_b_factor";               
        # }
        
        
        #die $line;
        my $file = $file_by_time_point {$time_point};
        print $file $line;
      }
    } else {
        ### Pour chaque time point du fichier PML
        foreach my $time_point (@sorted_time_points) {
          my $file = $file_by_time_point {$time_point};
          print $file $line;
        }
    }
  }

  close PDB_FILE;

  ### On ferme les fichiers de sorties
  foreach my $file (values(%file_by_time_point)) {
    close $file;
  }

  my $chain_idx = 0;
  for my $chain_name (sort keys %pdb_chain_idx_by_name) {
    $pdb_chain_idx_by_name{$chain_name} = $chain_idx;
    $chain_idx++;
  }
  my %b_factor_mapping = ();
  while ( my($chain_res_key, $bfactor_map) = each(%b_factor_list_by_res)) {
    my($chain_name,$res_idx) = split('%',$chain_res_key);
    
    # If chain exists in current PDB file
    if (exists $pdb_chain_idx_by_name{$chain_name}) {
      my $chain_idx = $pdb_chain_idx_by_name{$chain_name};

      while (my($time_point, $bfactor) = each(%$bfactor_map)) {
        $b_factor_mapping{$pdb_name_by_time_point{$time_point}}[$chain_idx][$res_idx] = $bfactor;
      }
    }
  }
  
  return (\@output_files,\%b_factor_mapping);
}

sub pdb2fasta($job_dir, $pdb_path) {
  my($pdb_name,$pdb_dir,$pdb_ext) = fileparse($pdb_path,'.pdb');
  $pdb_dir =~ s/\/$//;

  my %aa3to1=(
   'ALA'=>'A', 'VAL'=>'V', 'PHE'=>'F', 'PRO'=>'P', 'MET'=>'M',
   'ILE'=>'I', 'LEU'=>'L', 'ASP'=>'D', 'GLU'=>'E', 'LYS'=>'K',
   'ARG'=>'R', 'SER'=>'S', 'THR'=>'T', 'TYR'=>'Y', 'HIS'=>'H',
   'CYS'=>'C', 'ASN'=>'N', 'GLN'=>'Q', 'TRP'=>'W', 'GLY'=>'G',
   'MSE'=>'M',
  );
  
  my %chain_hash;

  open(PDB_FILE,'<',$pdb_path) or die $!;
  while (my $line = <PDB_FILE>) {
     #my ($v1, $aa, $v3) = unpack 'A17A3A60', $line;
     #print "$aa_table{ lc($aa) }";
    
    chomp($line);
    last if ($line=~/^ENDMDL/); # just the first model
    
    if ($line=~/^ATOM\s{2,6}\d{1,5}\s{2}CA\s[\sA]([A-Z]{3})\s([\s\w])\s+?(\d+)/
     or $line=~/^HETATM\s{0,4}\d{1,5}\s{2}CA\s[\sA](MSE)\s([\s\w])\s+?(\d+)/) {
      my $res3 = $1;
      my $chain = $2;
      my $resNumber = $3;
      #$chain_hash{$chain} = $chain_hash{$chain} . $aa3to1{uc($res3)}; # append current AA char
      $chain_hash{$chain}[$resNumber-1] = $aa3to1{uc($res3)};
    }
  }
  close PDB_FILE;
  
  #my $fasta_file_path = "$pdb_dir/$pdb_name.fasta";
  my $fasta_file_path = "$job_dir/$pdb_name.fasta";
  open(FASTA_FILE,'>',$fasta_file_path) or die $!;
  
  my @chains = sort keys %chain_hash;
  foreach my $chain (@chains){

    ### Insert X AA where no AA was found from PDB file
    my @aa_seq = @{$chain_hash{$chain}};
    my $aa_count = scalar(@aa_seq);
    my @new_aa_seq;
    for my $aa_idx (0..$aa_count-1) {
      my $aa = $aa_seq[$aa_idx] || 'X';
      push(@new_aa_seq,$aa);
    }
    my $seq = join('', @new_aa_seq);

    say FASTA_FILE ">$pdb_name:$chain\n$seq";
  }

  #say "fasta ok";
  
  close FASTA_FILE;

  return ($fasta_file_path, \@chains);
}


__DATA__

@@ index.html.ep
% my $url = url_for 'title';

<!DOCTYPE html>

<html lang="en">
<head>
  <meta charset="utf-8">
  
  <title>HDX viewer</title>
  <meta name="description" content="HDX-Viewer is an interactive 3D viewer of Hydrogen-Deuterium eXchange data.">
  <meta name="author" content="David Bouyssié">
  
  <style>
      * {
        margin: 0;
        padding: 0;
    }
    html,
    body {
        margin: 10px;
        width: 100%;
        /*height: 100%;*/
        /*overflow-x: hidden;*/
    }
  </style>
  
  <link href="./css/hdx_viewer.css" rel="stylesheet">
  
  <script>
    // Check Browser version
    if((navigator.userAgent.indexOf("MSIE") != -1 ) || (!!document.documentMode == true )) //IF IE > 10
      {
        alert('Your are using Internet Explorer.\nUnfortunatly this web browser is not supported by HDX-Viewer.\nPlease use Chrome, Firefox or Edge.'); 
      }
  </script>

  <!-- JQUERY !!! -->
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
  <script src="https://code.jquery.com/ui/1.12.1/jquery-ui.min.js"
          integrity="sha256-VazP97ZCwtekAsvgPBSUwPFKdrwD3unUfSGVYrahUqU="
          crossorigin="anonymous"></script>

  <!-- SCRIPTS FOR FILE UPLOAD (https://cdnjs.com/libraries/blueimp-file-upload) -->
  <!-- The jQuery UI widget factory, can be omitted if jQuery UI is already included -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/blueimp-file-upload/9.22.0/js/vendor/jquery.ui.widget.js"></script>
  <!-- The Iframe Transport is required for browsers without support for XHR file uploads -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/blueimp-file-upload/9.22.0/js/jquery.iframe-transport.js"></script>
  <!-- The basic File Upload plugin -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/blueimp-file-upload/9.22.0/js/jquery.fileupload.js"></script>

  <!-- SCRIPTS FOR BUSY LOADING DISPLAY -->
  <script src="https://cdn.jsdelivr.net/npm/busy-load@0.1.1/dist/app.min.js"></script>
  <link href="https://cdn.jsdelivr.net/npm/busy-load@0.1.1/dist/app.min.css" rel="stylesheet">
    
  <!-- SCRIPTS FOR NGL -->
  <script defer src="https://cdn.jsdelivr.net/gh/arose/ngl@v2.0.0-dev.33/dist/ngl.js"></script>
  <script defer src="https://cdnjs.cloudflare.com/ajax/libs/three.js/92/three.js"></script>
  <script defer src="https://cdnjs.cloudflare.com/ajax/libs/chroma-js/1.3.7/chroma.min.js"></script>
    
  <!-- SCRIPTS FOR MSA -->
  <script defer src="https://s3.eu-central-1.amazonaws.com/cdn.bio.sh/msa/1.0.3/msa.min.gz.js"></script>
  <!-- <script src="./js/msa-colorschemes.js"></script> -->

  <!-- SCRIPT FOR JS COLOR -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jscolor/2.0.4/jscolor.min.js"></script>
  
  <!-- SCRIPTS FOR CANVAS CAPTURE -->
  <!-- <script defer src="https://cdn.JsDelivr.net/npm/ccapture.js"></script> -->
  <script defer src="https://cdn.jsdelivr.net/npm/ccapture.js@1.1.0/build/CCapture.min.js"></script>
  <script defer src="https://cdnjs.cloudflare.com/ajax/libs/downloadjs/1.4.8/download.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/gif.js@0.2.0/dist/gif.min.js"></script>
  
  <!-- Load the application scripts -->
  <script src="./js/hdx-web-viewer.js?t=<?= time(); ?>"></script>
  
</head>

<body>
  <p></p>
  
  <h1>HDX Viewer <button id="btn-display-help" class="bouton" onclick="window.open('./help/index.html');" style="width: 100px; margin-left: 170px;" >HELP!</button> </h1>
  
  <table valign="top">
    <tbody>
      <tr>
        <td style="width: 600px;">

          <fieldset class="cadre" id="fieldset-files" style="padding: 10px"> <legend>Input Data</legend>

            <div style="height: 40px;">
              <span>
                <span id="spn-pml-format" >
                  <label>PML format: </label>
                  <input id="rad-dx-format" type="radio" name="pml-format" value="DynamX" style="margin-left: 20px" checked="checked" /> <label for="rad-dx-format" >DynamX</label>
                  <input id="rad-hde-format" type="radio" name="pml-format" value="HDExaminer"  style="margin-left: 20px" /> <label for="rad-hde-format" >HDExaminer</label>
                </span>
                
                <span id="spn-hde-chain" style="visibility: hidden;" >
                  <label for="lbl-sel-hde-chain">-> chain:</label>
                  <select id="sel-hde-chain" name="hde-chain" style="width: 80px;" ></select>
                </span>
                
              </span>
        
              <!-- The first file input field used as target for the file upload widget -->
              <span id="spn-pdb-upload" class="upload-btn-wrapper" style="float: left; margin-right: 20px;" >
              
                <button class="upload-btn">Upload PDB file</button>
                
                <label for="file-pdb" class="upload-label">
                
                  <input id="file-pdb" name="file" type="file" accept=".pdb" />
                
                </label>
                
              </span>
              
              <!-- The second file input field used as target for the file upload widget -->
              <span id="spn-pml-upload" class="upload-btn-wrapper" style="float: left; display: none;" >
              
                <button class="upload-btn">Upload PML files</button>
                
                <label for="file-pml" class="upload-label">
                
                  <input id="file-pml" name="files[]" multiple="" type="file" accept=".pml" />
                
                </label>
                
              </span>
              
              <span style="float: left; margin-left: 20px;">
                <button class="bouton" style="width: 120px; display: none" onclick="processLoadedFiles()"><b>Process files!</b></button>
              </span>
              
            </div>
            
            <div style="height: 40px; margin-top: 20px; padding-top: 20px;">
            
              <span style="float: left; margin-right: 20px;">
                <button class="bouton" onclick="loadDemoFiles()">Load demo files</button>
              </span>
              
              <span style="float: left">
                <button id="btn-download-results" class="bouton" onclick="downloadOutputFiles()" style="display: none;">Download results</button>
              </span>
            </div>
            
            <!-- The global progress bar -->
            <div id="progress" class="progress" >
              <div class="progress-bar progress-bar-success"></div>
            </div>
              
            <!-- The container for the uploaded files -->
            <div id="div-uploaded-files" class="files" style="margin-top: 10px;"></div>
            
          </fieldset>
          
          <br/>

          <fieldset class="cadre">&nbsp; <legend>Viewer Options</legend>
            <span><b>Deuteration Color Options:</b></span>
            <table>
              <tbody>
                <tr>
                  <td style="width: 180px;">Deuteration Range (%):</td>
                  <td><input id="txt-ngl-bfactor-min" required="" placeholder="Min value" type="text"></td>
                  <td><input id="txt-ngl-bfactor-max" required="" placeholder="Max value" type="text"></td>
                </tr>
                <tr>
                  <td colspan="3" class="tdbutton"><button class="bouton" type="button" onclick="setBFactorRange()">Apply</button> </td>
                </tr>
              </tbody>
            </table>
            <table>
              <tbody>
                <tr>
                  <td>Color Scale:</td>
                  <td>
                    <select id="sel-ngl-color-scale" name="ngl-color-scale">
                      <option value="custom">Custom</option>
                      <option value="blue-red" selected="selected">Blue-Red</option>
                      <option value="blue-white-red">Blue-White-Red</option>
                      <option value="red-white-blue">Red-White-Blue</option>
                    </select>
                  </td>
                  
                  <td>Min Value Color:</td>
                  <td>
                    <button id="btn-ngl-min-value-color" class="bouton jscolor" data-jscolor="{valueElement:null,value:'0000ff'}" style="width: 50px; height: 20px"></button>
                  </td>
                </tr>
                <tr>
                  <td><br>
                  </td>
                  <td><br>
                  </td>
                  <td>Max Value Color:</td>
                  <td>
                    <button id="btn-ngl-max-value-color" class="bouton jscolor" data-jscolor="{valueElement:null,value:'ff0000'}" style="width: 50px; height: 20px;"></button>
                  </td>
                </tr>
              </tbody>
            </table>
            <table>
              <tbody>
                <tr>
                  <td style="width: 200px;">Undetected Region Color:</td>
                  <td>
                    <select id="sel-ngl-nodata-color" name="ngl-nodata-color">
                      <option value="black">black</option>
                      <option value="grey" selected="selected">grey</option>
                      <option value="white">white</option>
                    </select>
                  </td>
                </tr>
                <tr>
                  <td>Background Color :</td>
                  <td>
                    <select id="sel-ngl-bgcolor" name="ngl-bgcolor">
                      <option value="black" selected="selected">black</option>
                      <option value="white">white</option>
                    </select>
                  </td>
                </tr>
              </tbody>
            </table>
            <p> </p>
            <hr>
            <table>
              <tbody>
                <tr>
                  <td class="tdtitre">Representation:</td>
                  <td>
                    <select id="sel-ngl-repr" name="ngl-repr">
                      <!-- <option value="axes">axes</option> -->
                      <option value="backbone">backbone</option>
                      <option value="ball+stick">ball+stick</option>
                      <!-- <option value="base">base</option> -->
                      <option value="cartoon" selected="selected">cartoon</option>
                      <option value="contact">contact</option>
                      <!-- <option value="distance">distance</option> -->
                      <!-- <option value="helixorient">helixorient</option> -->
                      <option value="hyperball">hyperball</option>
                      <!-- <option value="label">label</option> -->
                      <option value="licorice">licorice</option>
                      <option value="line">line</option>
                      <option value="point">point</option>
                      <option value="ribbon">ribbon</option>
                      <option value="rocket">rocket</option>
                      <option value="rope">rope</option>
                      <option value="spacefill">spacefill</option>
                      <option value="surface">surface</option>
                      <option value="trace">trace</option>
                      <option value="tube">tube</option>
                      <!-- <option value="unitcell">unitcell</option> -->
                      <!-- <option value="validation">validation</option> -->
                    </select>
                  </td>
                  <td><br>
                  </td>
                </tr>
              </tbody>
            </table>
            <p> </p>
            <hr>
            <table>
              <tbody>
                <tr>
                  <td class="tdtitre">Spinning options: </td>
                  <td>Angle (radians): </td>
                  <td>
                    <input id="txt-ngl-spinning-angle" required="" placeholder="Amount to spin per frame (radians)" value="0.005" type="text">
                  </td>
                </tr>
                <tr>
                  <td colspan="3" class="tdbutton">
                    <button class="bouton" type="button" id="btn-ngl-spinning-ctrl" onclick="toggleSpinning()">Start spinning</button>
                  </td>
                </tr>
              </tbody>
            </table>
            <p></p>
            <hr>
            <p></p>
            <table>
              <tbody>
                <tr>
                  <td class="tdtitre">Animation options:</td>
                  <td><input id="cbx-ngl-animation-loop" name="loop-forever" value="true" checked="checked" type="checkbox">
                      <label for="cbx-ngl-animation-loop">Loop forever</label>
                  </td>
                  <td><br /></td>
                </tr>
                <tr>
                  <td><br /></td>
                  <td>Delay (ms):</td>
                  <td>
                    <input id="txt-ngl-animation-delay" required="" placeholder="Delay between frames (ms)" value="1000" type="text" />
                  </td>
                </tr>
                <tr>
                  <td colspan="3" class="tdbutton">
                    <button class="bouton" type="button" id="btn-ngl-animation-ctrl" onclick="toggleStructureAnimation()">Start animation</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </fieldset>
        </td>
        
        <td valign="top">
          <div id="viewport" style="width:90%; min-width: 600px; max-width: 800px; height:600px; margin: 10px; margin-top: 30px;"></div>
          
          <div>
            <span style="margin: 10px;">
              <button type="button" class="bouton" onclick="switchToFullScreen()">Full screen mode</button>
              <button type="button" class="bouton" onclick="exportImage()">Export as PNG</button>
              <button type="button" class="bouton" onclick="savePosition()">Save orientation</button>
              <button type="button" class="bouton" onclick="restorePosition()">Restore orientation</button>
            </span>
          </div>
          
          <br />
          
          <div>
            <span style="margin: 10px;">
              <button type="button" class="bouton" onclick="toggleGIFRecording()" id="btn-gif-recording-ctrl" >Record GIF</button>
            </span>
            
          </div>
          
          <div style="margin: 10px;">
            <img src="./img/loader-mask-black.gif" alt="Recording..." id="img-gif-recording" height="32" width="32" style="display: none;" />
          </div>
          
        </td>
        
      </tr>
    </tbody>
  </table>
  
  <p><br>
  </p>
  <p> <br>
  </p>
  
  <div height="200">
    <div id="div-fasta" ></div>
  </div>
  
</body>
</html>
