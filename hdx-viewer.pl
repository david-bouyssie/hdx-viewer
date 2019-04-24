#!C:/Perl64/bin/perl.exe -w

use strict;
use 5.20.0;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Data::Dumper;
use File::Basename;
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

### TODO: create a job directory
my $UPLOAD_DIR = "./public/uploads/";
my $last_job_number = 0;

# Render template "index.html.ep" from the DATA section
get '/' => sub ($c) {
  $c->render(template => 'index');
};

# Multipart upload handler
post '/upload' => sub {
  my $c = shift;

  # Check file size
  return $c->render(json => {error => "One of the files is too big"}, status => 200) if $c->req->is_limit_exceeded;
  
  $last_job_number += 1;
  
  my $uid_as_str = _generate_job_uid($last_job_number);
  my $job_dir = $UPLOAD_DIR . "/job_$uid_as_str";
  mkdir($job_dir);
  mkdir("$job_dir/input");
  
  #my @files;
  my $pdb_file_path;
  my $pml_file_path;
  for my $file (@{$c->req->uploads('files')}) {
    my $size = $file->size;
    my $name = $file->filename;
    my $uploaded_file_location = $job_dir . '/input/' . $file->filename;
    say "uploaded_file_location: $uploaded_file_location";
    
    $file->move_to($uploaded_file_location);
    if ($name =~ /.+\.pdb/) {$pdb_file_path = $uploaded_file_location; }
    if ($name =~ /.+\.pml/) {$pml_file_path = $uploaded_file_location; }
    #push(@files, $file->filename);
  }
   
  if ($pdb_file_path && $pml_file_path) {
    my ($output_files, $bfactor_mapping) = pml2pdb($job_dir, $pdb_file_path, $pml_file_path);
    my $fasta_file = pdb2fasta($job_dir, $pdb_file_path);
    
    $c->render(json => {pdb_files => $output_files, fasta_file => $fasta_file, bfactor_mapping => $bfactor_mapping} );
  } else {
    $c->render(json => {error => "Invalid input: wrong PDB/PML file formats"} );
  }
};

sub _generate_job_uid($job_number) {
  ### See: https://stackoverflow.com/questions/30731917/generate-a-unique-id-in-perl
  my $random_id = join '', map int rand 10, 1..6 ;
  my $uid_as_str = $random_id.'-'.time."-$job_number"; #Data::GUID->new->as_string;
  return $uid_as_str;
}

get '/test' => sub ($c) {
  say "hello";
  $c->render(text => 'I ♥ Mojolicious!');
};

get '/download_results' => sub ($c) {
  #say "hello";
  
  #my $files = $c->req->json;
  my $fasta_file = $c->param('fasta_file');
  my @pdb_files = @{$c->every_param('pdb_files[]')};
  
  if (not $fasta_file =~ /^\.\/public/) {
    #say "invalid fasta_file file location";
    return $c->reply->exception("invalid fasta_file file location");
  }
  
  my( $job_dir, $job_suffix);
  if ($fasta_file =~ /^\.\/public\/demo/ ) {
    $job_dir = './public/demo';
    $job_suffix = 'demo-dataset';
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

under sub {
  my $c = shift;
  say "test globals";
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
    #print $line;
    if ($line =~ /alter \/\w+\/\/(\w+)\/(\d+), properties\[".*?(\d+\s\w+)"\] = ([-]?\d+[\.,]?\d*)/) { # (\w+) was ([A-Z]+) but we need also numbers for chains
      my $chains = $1;
      my $residue_pos = $2;
      my $time_point = $3;
      my $b_factor = $4 + 0;
      #say "residue_pos $residue_pos b_factor = $b_factor";
      
      $time_point =~ s/\s/_/g;

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

  ### On ouvre en écriture autant de fichier que de time points
  my @output_files;
  my %pdb_name_by_time_point = ();

  my %file_by_time_point = map {
    my $time_point = $_;
    
    my $pdb_name = $pml_name."_$time_point.pdb";
    $pdb_name_by_time_point{$time_point} = $pdb_name;

    #my $pdb_path = $pdb_dir.'/'.$pdb_name;
    my $pdb_path = $job_dir.'/'.$pdb_name;
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
    if ($line =~ /ATOM\s+\d+\s+\w+\s+\w+\s+([A-Z])\s+(-*\d+)/ || $line =~ /HETATM\s+\d+\s+\w+\s+\w+\s+([A-Z])\s+(-*\d+)/) {
    
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
        if ($line =~ /(ATOM\s+\d+\s+\w+\s+\w+\s+[A-Z]\s+\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2})(\s*)(\S+)(\s+)([A-Z]\s*)/ ||
            $line =~ /(HETATM\s+\d+\s+\w+\s+\w+\s+[A-Z]\s+\d+\s+\S+\s+\S+\s+\S+\s+\d+\.\d{2})(\s*)(\S+)(\s+)([A-Z]\s*)/
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
          
          my $new_space_len = ($before_b_factor_space_len -1 ) + ($old_b_factor_len + $space_len) - $b_factor_len;
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
  
  foreach my $chain(sort keys %chain_hash){

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

  return $fasta_file_path;
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
  <h1>HDX Viewer</h1>
  <table valign="top">
    <tbody>
      <tr>
        <td style="width: 600px;">

          <fieldset class="cadre" id="fieldset-files" style="padding: 10px"> <legend>Input Data</legend>
            <div style="height: 40px;">
              <span style="float: left; margin-right: 20px;">
                <button class="bouton" onclick="loadDemoFiles()">Load demo files</button>
              </span>
              
              <!-- The file input field used as target for the file upload widget -->
              <span class="upload-btn-wrapper" style="float: left;">
              
                <button class="upload-btn">Upload PDB/PML files</button>
                
                <label for="fileupload" class="upload-label">
                
                  <input id="fileupload" name="files[]" multiple="" type="file"  />
                
                </label>
                
              </span>

              <span style="float: left; margin-left: 20px;">
                <button class="bouton" onclick="downloadOutputFiles()">Download results</button>
              </span>
              
            </div>
            
            <!-- The global progress bar -->
            <div id="progress" class="progress">
              <div class="progress-bar progress-bar-success"></div>
            </div>
              
            <!-- The container for the uploaded files -->
            <div id="uploaded-files" class="files" style="margin-top: 10px;"></div>
            
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



