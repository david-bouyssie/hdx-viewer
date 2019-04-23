//var ws = new WebSocket('<%= $url->to_abs %>');
//ws.onmessage = function (event) { document.body.innerHTML += event.data };
//ws.onopen    = function (event) { ws.send('https://mojolicious.org') };

function componentToHex(c) {
  var hex = c.toString(16);
  return hex.length == 1 ? "0" + hex : hex;
}

function rgbToHex(r, g, b) {
  return "#" + componentToHex(r) + componentToHex(g) + componentToHex(b);
}

//function rgbToHex(rgb) {
//  return "#" + ((1 << 24) + (rgb[0] << 16) + (rgb[1] << 8) + rgb[2]).toString(16).slice(1);
//}

function hexToRGB(hex){
  var r = hex >> 16;
  var g = hex >> 8 & 0xFF;
  var b = hex & 0xFF;
  return [r,g,b];
}

function decimalColorToHex(decimal) {
  let rgb = hexToRGB(decimal);
  return rgbToHex(rgb[0],rgb[1],rgb[2]).toUpperCase();
}

function getFileName(filePath) {
  return filePath.split('\\').pop().split('/').pop();
}

// Global variables
var nglStage;
var nglFullScreenOn = false;
var nglMinBFactor;
var nglMaxBFactor;
var nglBFactorOffset = 0;
var nglColorScale;
var nglColorScheme;
var nglUndetectedRegionColor = 'grey';
var nglStructByName = {};
var nglReprByName = {};
var nglOrientations = [];
var nglSelectedPdbFilePath;
var selectedResNumber = -1;
var lastRespAsJSON = null;
var datasetTmpId = 1;

window.onload = function() {
  init();
  
  var url = "/upload";
  
  $('#fileupload').fileupload({
    url: url,
    singleFileUploads: false,
    multipart: true,
    dataType: 'json',
    done: function (e, data) {
    
      var respAsJSON = data.jqXHR.responseJSON;
      lastRespAsJSON = respAsJSON;
      
      addFilesToSelectBox(respAsJSON.pdb_files, respAsJSON.fasta_file);
    },
    progressall: function (e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      $('#progress .progress-bar').css(
        'width',
        progress + '%'
      );
    }
  });
};

function addFilesToSelectBox(pdb_files, fasta_file) {

  //console.log(pdb_files);
  //console.log(fasta_file);
  
  // First we reset the previously loaded files
  $( "#uploaded-files" ).empty();
  
  // Reset NGL stage and other related variables
  nglStage.removeAllComponents();
  nglStructByName = {};
  nglReprByName = {};
  nglOrientations = [];
  nglSelectedPdbFilePath = null;
  selectedResNumber = -1;
  datasetTmpId = 1;

  // Then we add new files
  var selectBoxAsStr = `<select id="sel-ngl-pdb-output-${datasetTmpId}" name="ngl-pdb-output" class="pdb-select-box">\n`;
  $.each(pdb_files, function (index, pdbFilePath) {

    let pdbFileName = getFileName(pdbFilePath);

    selectBoxAsStr += `<option value="${pdbFilePath}">${pdbFileName}</option>\n`;
    
    /*$('<input type="checkbox" id="file-'+index+'" name="pdb-file" value="'+pdbFilePath+'" /><label for="file-'+index+'">'+pdbFileName+'</label>').appendTo('#fieldset-files');
    
    let pdbFileURL = './' + pdbFilePath.split("public/").pop();
    $('#file-'+index).change( function(){
      //if ($(this).is(':checked')) {
      if (this.checked) {
        addStructure(pdbFileURL, pdbFileName);
      } else {
        nglReprByName[pdbFileName].dispose();
        delete nglReprByName[pdbFileName];
        delete nglStructByName[pdbFileName];
      }
    });*/
  });

  selectBoxAsStr += "</select>\n";

  $(selectBoxAsStr).appendTo('#uploaded-files');

  // Display first structure of the list
  nglSelectedPdbFilePath = $(`#sel-ngl-pdb-output-${datasetTmpId} option:first`).val();
  replaceStructure(nglSelectedPdbFilePath, true, function(loadedComponent) {
  
    /*loadedComponent.structure.eachAtom(function (a) {
      let bfactor = a.bfactor;
      console.log("atom bfactor: ", a.resno, bfactor);
    });*/
  
    // Call autoView only once
    loadedComponent.autoView();
    
    // Run later
    /*setTimeout(function(){

      let fastaURL = './' + fasta_file.split("public/").pop();
      //console.log(fastaURL);
      displayFastaFile(fastaURL);
      
      //var fastaText = document.getElementById("fasta-file").innerText;
      //var seqs = msa.io.fasta.parse(fastaText);  
    },
    500
    );*/
 
  });

  // Listen for select box changes
  $( "#sel-ngl-pdb-output-"+datasetTmpId ).change(function(e) {
    let pdbFilePath = $(e.target).val();
    nglSelectedPdbFilePath = pdbFilePath;
    replaceStructure(pdbFilePath, true);
  });
  datasetTmpId++;
  
  let fastaURL = './' + fasta_file.split("public/").pop();
  //console.log(fastaURL);
  displayFastaFile(fastaURL);
}

function loadDemoFiles() {
  let demoRespAsJSON = {"bfactor_mapping":{"SecB_C4_10_min.pdb":[[null,null,null,0.033,0.033,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.036,0.036,0.036,0.036,0.036,0.036,null,null,0.036,0.036,0.036,0.036,0.036,0.036,0.036,null,null,null,null,0.009,0.009,0.009,0.009,0.009,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.039,0.039,0.039,0.039,0.081,0.081,0.081,0.081,0.081,0.081,0.046,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.039,0.012,0.009,0.009,0.009,0.009,0.009,0.01,0.01,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.006,-0.009,-0.009,-0.009,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,null,0.005,0.005,0.005,0.005,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.049,0.003,0.003,0.003,0.003,0.029,0.026,0.026,0.033,0.033,0.033,0.033,0.033,0.023,0.002,0.002,0.002,0.018,0.018,0.018,0.018,0.024,-0.005,-0.005,-0.005,-0.005,-0.005,-0.005,-0.004,-0.004,0.099,0.15,0.142,0.142,0.142,0.142,0.15,0.024,0.025,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.035,0.035,0.035,0.035,0.035,0.035,0.035,0.035],[null,null,null,0.033,0.033,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.036,0.036,0.036,0.036,0.036,0.036,null,null,0.036,0.036,0.036,0.036,0.036,0.036,0.036,null,null,null,null,0.009,0.009,0.009,0.009,0.009,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.039,0.039,0.039,0.039,0.081,0.081,0.081,0.081,0.081,0.081,0.046,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.039,0.012,0.009,0.009,0.009,0.009,0.009,0.01,0.01,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.006,-0.009,-0.009,-0.009,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,null,0.005,0.005,0.005,0.005,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.049,0.003,0.003,0.003,0.003,0.029,0.026,0.026,0.033,0.033,0.033,0.033,0.033,0.023,0.002,0.002,0.002,0.018,0.018,0.018,0.018,0.024,-0.005,-0.005,-0.005,-0.005,-0.005,-0.005,-0.004,-0.004,0.099,0.15,0.142,0.142,0.142,0.142,0.15,0.024,0.025,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.035,0.035,0.035,0.035,0.035,0.035,0.035,0.035],[null,null,null,0.033,0.033,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.036,0.036,0.036,0.036,0.036,0.036,null,null,0.036,0.036,0.036,0.036,0.036,0.036,0.036,null,null,null,null,0.009,0.009,0.009,0.009,0.009,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.039,0.039,0.039,0.039,0.081,0.081,0.081,0.081,0.081,0.081,0.046,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.039,0.012,0.009,0.009,0.009,0.009,0.009,0.01,0.01,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.006,-0.009,-0.009,-0.009,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,null,0.005,0.005,0.005,0.005,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.049,0.003,0.003,0.003,0.003,0.029,0.026,0.026,0.033,0.033,0.033,0.033,0.033,0.023,0.002,0.002,0.002,0.018,0.018,0.018,0.018,0.024,-0.005,-0.005,-0.005,-0.005,-0.005,-0.005,-0.004,-0.004,0.099,0.15,0.142,0.142,0.142,0.142,0.15,0.024,0.025,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.035,0.035,0.035,0.035,0.035,0.035,0.035,0.035],[null,null,null,0.033,0.033,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.049,0.036,0.036,0.036,0.036,0.036,0.036,null,null,0.036,0.036,0.036,0.036,0.036,0.036,0.036,null,null,null,null,0.009,0.009,0.009,0.009,0.009,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.019,0.039,0.039,0.039,0.039,0.081,0.081,0.081,0.081,0.081,0.081,0.046,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.039,0.012,0.009,0.009,0.009,0.009,0.009,0.01,0.01,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.028,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.006,-0.009,-0.009,-0.009,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,null,0.005,0.005,0.005,0.005,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.049,0.003,0.003,0.003,0.003,0.029,0.026,0.026,0.033,0.033,0.033,0.033,0.033,0.023,0.002,0.002,0.002,0.018,0.018,0.018,0.018,0.024,-0.005,-0.005,-0.005,-0.005,-0.005,-0.005,-0.004,-0.004,0.099,0.15,0.142,0.142,0.142,0.142,0.15,0.024,0.025,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.039,0.035,0.035,0.035,0.035,0.035,0.035,0.035,0.035]],"SecB_C4_30_min.pdb":[[null,null,null,0.024,0.024,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.021,0.021,0.021,0.021,0.021,0.021,null,null,0.069,0.069,0.069,0.069,0.069,0.069,0.069,null,null,null,null,0.017,0.017,0.017,0.017,0.017,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.03,0.03,0.03,0.03,0.101,0.101,0.101,0.101,0.101,0.101,0.052,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.043,0.027,0.03,0.03,0.03,0.03,0.03,0.023,0.023,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,-0.007,-0.011,-0.011,-0.011,-0.001,-0.001,-0.001,-0.001,-0.007,-0.007,-0.007,null,0,0,0,0,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.046,0.021,0.021,0.021,0.021,0.042,0.041,0.041,0.045,0.045,0.045,0.045,0.045,0.039,0.006,0.006,0.006,0.012,0.012,0.012,0.012,0.025,-0.004,-0.004,-0.004,-0.004,-0.004,-0.004,-0.003,-0.003,0.101,0.157,0.174,0.174,0.174,0.174,0.157,0.025,0.026,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029],[null,null,null,0.024,0.024,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.021,0.021,0.021,0.021,0.021,0.021,null,null,0.069,0.069,0.069,0.069,0.069,0.069,0.069,null,null,null,null,0.017,0.017,0.017,0.017,0.017,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.03,0.03,0.03,0.03,0.101,0.101,0.101,0.101,0.101,0.101,0.052,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.043,0.027,0.03,0.03,0.03,0.03,0.03,0.023,0.023,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,-0.007,-0.011,-0.011,-0.011,-0.001,-0.001,-0.001,-0.001,-0.007,-0.007,-0.007,null,0,0,0,0,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.046,0.021,0.021,0.021,0.021,0.042,0.041,0.041,0.045,0.045,0.045,0.045,0.045,0.039,0.006,0.006,0.006,0.012,0.012,0.012,0.012,0.025,-0.004,-0.004,-0.004,-0.004,-0.004,-0.004,-0.003,-0.003,0.101,0.157,0.174,0.174,0.174,0.174,0.157,0.025,0.026,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029],[null,null,null,0.024,0.024,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.021,0.021,0.021,0.021,0.021,0.021,null,null,0.069,0.069,0.069,0.069,0.069,0.069,0.069,null,null,null,null,0.017,0.017,0.017,0.017,0.017,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.03,0.03,0.03,0.03,0.101,0.101,0.101,0.101,0.101,0.101,0.052,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.043,0.027,0.03,0.03,0.03,0.03,0.03,0.023,0.023,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,-0.007,-0.011,-0.011,-0.011,-0.001,-0.001,-0.001,-0.001,-0.007,-0.007,-0.007,null,0,0,0,0,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.046,0.021,0.021,0.021,0.021,0.042,0.041,0.041,0.045,0.045,0.045,0.045,0.045,0.039,0.006,0.006,0.006,0.012,0.012,0.012,0.012,0.025,-0.004,-0.004,-0.004,-0.004,-0.004,-0.004,-0.003,-0.003,0.101,0.157,0.174,0.174,0.174,0.174,0.157,0.025,0.026,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029],[null,null,null,0.024,0.024,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.04,0.021,0.021,0.021,0.021,0.021,0.021,null,null,0.069,0.069,0.069,0.069,0.069,0.069,0.069,null,null,null,null,0.017,0.017,0.017,0.017,0.017,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.023,0.03,0.03,0.03,0.03,0.101,0.101,0.101,0.101,0.101,0.101,0.052,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.018,0.043,0.027,0.03,0.03,0.03,0.03,0.03,0.023,0.023,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.026,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,-0.007,-0.011,-0.011,-0.011,-0.001,-0.001,-0.001,-0.001,-0.007,-0.007,-0.007,null,0,0,0,0,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.03,0.046,0.021,0.021,0.021,0.021,0.042,0.041,0.041,0.045,0.045,0.045,0.045,0.045,0.039,0.006,0.006,0.006,0.012,0.012,0.012,0.012,0.025,-0.004,-0.004,-0.004,-0.004,-0.004,-0.004,-0.003,-0.003,0.101,0.157,0.174,0.174,0.174,0.174,0.157,0.025,0.026,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.043,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029]],"SecB_C4_30_sec.pdb":[[null,null,null,0.03,0.03,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.086,0.086,0.086,0.086,0.086,0.086,null,null,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,null,null,null,null,0.012,0.012,0.012,0.012,0.012,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.069,0.069,0.069,0.069,0.023,0.023,0.023,0.023,0.023,0.023,0.043,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.047,-0.007,0.001,0.001,0.001,0.001,0.001,0,0,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,-0.003,-0.006,-0.006,-0.006,-0.008,-0.008,-0.008,-0.008,-0.011,-0.011,-0.011,null,0.003,0.003,0.003,0.003,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.03,0.005,0.005,0.005,0.005,0.012,0.016,0.016,0.014,0.014,0.014,0.014,0.014,0.007,0,0,0,-0.001,-0.001,-0.001,-0.001,0.024,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,0,0,0.055,0.094,0.095,0.095,0.095,0.095,0.094,0.024,0.025,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.014,0.014,0.014,0.014,0.014,0.014,0.014,0.014],[null,null,null,0.03,0.03,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.086,0.086,0.086,0.086,0.086,0.086,null,null,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,null,null,null,null,0.012,0.012,0.012,0.012,0.012,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.069,0.069,0.069,0.069,0.023,0.023,0.023,0.023,0.023,0.023,0.043,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.047,-0.007,0.001,0.001,0.001,0.001,0.001,0,0,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,-0.003,-0.006,-0.006,-0.006,-0.008,-0.008,-0.008,-0.008,-0.011,-0.011,-0.011,null,0.003,0.003,0.003,0.003,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.03,0.005,0.005,0.005,0.005,0.012,0.016,0.016,0.014,0.014,0.014,0.014,0.014,0.007,0,0,0,-0.001,-0.001,-0.001,-0.001,0.024,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,0,0,0.055,0.094,0.095,0.095,0.095,0.095,0.094,0.024,0.025,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.014,0.014,0.014,0.014,0.014,0.014,0.014,0.014],[null,null,null,0.03,0.03,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.086,0.086,0.086,0.086,0.086,0.086,null,null,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,null,null,null,null,0.012,0.012,0.012,0.012,0.012,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.069,0.069,0.069,0.069,0.023,0.023,0.023,0.023,0.023,0.023,0.043,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.047,-0.007,0.001,0.001,0.001,0.001,0.001,0,0,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,-0.003,-0.006,-0.006,-0.006,-0.008,-0.008,-0.008,-0.008,-0.011,-0.011,-0.011,null,0.003,0.003,0.003,0.003,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.03,0.005,0.005,0.005,0.005,0.012,0.016,0.016,0.014,0.014,0.014,0.014,0.014,0.007,0,0,0,-0.001,-0.001,-0.001,-0.001,0.024,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,0,0,0.055,0.094,0.095,0.095,0.095,0.095,0.094,0.024,0.025,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.014,0.014,0.014,0.014,0.014,0.014,0.014,0.014],[null,null,null,0.03,0.03,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.086,0.086,0.086,0.086,0.086,0.086,null,null,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,-0.006,null,null,null,null,0.012,0.012,0.012,0.012,0.012,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.041,0.069,0.069,0.069,0.069,0.023,0.023,0.023,0.023,0.023,0.023,0.043,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.046,0.047,-0.007,0.001,0.001,0.001,0.001,0.001,0,0,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,0.02,-0.003,-0.006,-0.006,-0.006,-0.008,-0.008,-0.008,-0.008,-0.011,-0.011,-0.011,null,0.003,0.003,0.003,0.003,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.03,0.005,0.005,0.005,0.005,0.012,0.016,0.016,0.014,0.014,0.014,0.014,0.014,0.007,0,0,0,-0.001,-0.001,-0.001,-0.001,0.024,-0.003,-0.003,-0.003,-0.003,-0.003,-0.003,0,0,0.055,0.094,0.095,0.095,0.095,0.095,0.094,0.024,0.025,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.029,0.014,0.014,0.014,0.014,0.014,0.014,0.014,0.014]],"SecB_C4_5_min.pdb":[[null,null,null,0.031,0.031,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.046,0.046,0.046,0.046,0.046,0.046,null,null,0.027,0.027,0.027,0.027,0.027,0.027,0.027,null,null,null,null,0.002,0.002,0.002,0.002,0.002,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.047,0.047,0.047,0.047,0.066,0.066,0.066,0.066,0.066,0.066,0.036,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.033,0.001,0.006,0.006,0.006,0.006,0.006,0.003,0.003,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.012,-0.008,-0.008,-0.008,-0.005,-0.005,-0.005,-0.005,-0.007,-0.007,-0.007,null,-0.001,-0.001,-0.001,-0.001,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.037,0.002,0.002,0.002,0.002,0.023,0.025,0.025,0.026,0.026,0.026,0.026,0.026,0.021,0.004,0.004,0.004,0.008,0.008,0.008,0.008,0.019,-0.008,-0.008,-0.008,-0.008,-0.008,-0.008,-0.001,-0.001,0.089,0.135,0.138,0.138,0.138,0.138,0.135,0.019,0.021,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022],[null,null,null,0.031,0.031,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.046,0.046,0.046,0.046,0.046,0.046,null,null,0.027,0.027,0.027,0.027,0.027,0.027,0.027,null,null,null,null,0.002,0.002,0.002,0.002,0.002,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.047,0.047,0.047,0.047,0.066,0.066,0.066,0.066,0.066,0.066,0.036,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.033,0.001,0.006,0.006,0.006,0.006,0.006,0.003,0.003,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.012,-0.008,-0.008,-0.008,-0.005,-0.005,-0.005,-0.005,-0.007,-0.007,-0.007,null,-0.001,-0.001,-0.001,-0.001,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.037,0.002,0.002,0.002,0.002,0.023,0.025,0.025,0.026,0.026,0.026,0.026,0.026,0.021,0.004,0.004,0.004,0.008,0.008,0.008,0.008,0.019,-0.008,-0.008,-0.008,-0.008,-0.008,-0.008,-0.001,-0.001,0.089,0.135,0.138,0.138,0.138,0.138,0.135,0.019,0.021,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022],[null,null,null,0.031,0.031,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.046,0.046,0.046,0.046,0.046,0.046,null,null,0.027,0.027,0.027,0.027,0.027,0.027,0.027,null,null,null,null,0.002,0.002,0.002,0.002,0.002,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.047,0.047,0.047,0.047,0.066,0.066,0.066,0.066,0.066,0.066,0.036,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.033,0.001,0.006,0.006,0.006,0.006,0.006,0.003,0.003,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.012,-0.008,-0.008,-0.008,-0.005,-0.005,-0.005,-0.005,-0.007,-0.007,-0.007,null,-0.001,-0.001,-0.001,-0.001,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.037,0.002,0.002,0.002,0.002,0.023,0.025,0.025,0.026,0.026,0.026,0.026,0.026,0.021,0.004,0.004,0.004,0.008,0.008,0.008,0.008,0.019,-0.008,-0.008,-0.008,-0.008,-0.008,-0.008,-0.001,-0.001,0.089,0.135,0.138,0.138,0.138,0.138,0.135,0.019,0.021,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022],[null,null,null,0.031,0.031,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.044,0.046,0.046,0.046,0.046,0.046,0.046,null,null,0.027,0.027,0.027,0.027,0.027,0.027,0.027,null,null,null,null,0.002,0.002,0.002,0.002,0.002,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.013,0.047,0.047,0.047,0.047,0.066,0.066,0.066,0.066,0.066,0.066,0.036,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.027,0.033,0.001,0.006,0.006,0.006,0.006,0.006,0.003,0.003,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.025,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022,-0.012,-0.008,-0.008,-0.008,-0.005,-0.005,-0.005,-0.005,-0.007,-0.007,-0.007,null,-0.001,-0.001,-0.001,-0.001,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.024,0.037,0.002,0.002,0.002,0.002,0.023,0.025,0.025,0.026,0.026,0.026,0.026,0.026,0.021,0.004,0.004,0.004,0.008,0.008,0.008,0.008,0.019,-0.008,-0.008,-0.008,-0.008,-0.008,-0.008,-0.001,-0.001,0.089,0.135,0.138,0.138,0.138,0.138,0.135,0.019,0.021,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.022,0.022,0.022,0.022,0.022,0.022,0.022,0.022]]},
    "fasta_file":"./public/demo/SecB_C4.fasta",
    "pdb_files":[
      "./public/demo/SecB_C4_30_sec.pdb",
      "./public/demo/SecB_C4_5_min.pdb",
      "./public/demo/SecB_C4_10_min.pdb",
      "./public/demo/SecB_C4_30_min.pdb"
    ]
  };
  lastRespAsJSON = demoRespAsJSON;

  addFilesToSelectBox(demoRespAsJSON.pdb_files, demoRespAsJSON.fasta_file);
}

function calcResidueColorforHDX(colorScale, residueNumber, bfactor) {
  let newColor = null;
  if (residueNumber == selectedResNumber) newColor = 0x00FF00;
  else if (bfactor == -1) {
    if (nglUndetectedRegionColor == 'black') newColor = 0x000000;
    else if (nglUndetectedRegionColor == 'grey') newColor = 0xAAAAAA;
    else if (nglUndetectedRegionColor == 'white') newColor = 0xFFFFFF;
    else newColor = 0xAAAAAA;
  }
  else {
    var value = bfactor + nglBFactorOffset;
    newColor = colorScale(value);
  }

  return newColor;
}

function createNglColorScheme(gradientColorScale) {
  // See:
  // - http://nglviewer.org/ngl/api/manual/coloring.html#custom-coloring
  // - https://github.com/arose/ngl/blob/master/src/color/colormaker.ts
  // - http://nglviewer.org/ngl/api/file/src/color/bfactor-colormaker.js.html
  // - https://github.com/arose/ngl/tree/master/examples/scripts/showcase/qmean.js
  // - https://github.com/arose/ngl/blob/e8713514cfa7100a8313b3ff34a3c94b4125ced4/src/color/colormaker-registry.ts
  // - https://github.com/arose/ngl/issues/556

  // FIXME: check if we need to remove schemes from the registry
  nglColorScheme = NGL.ColormakerRegistry.addScheme(function (params) {
    let min = Infinity;
    let max = -Infinity;
    
    let selection;
    params.structure.eachAtom(function (a) {
      let bfactor = a.bfactor;

      if (bfactor != -1) {
        min = Math.min(min, bfactor);
        if (bfactor < 30) max = Math.max(max, bfactor);
      }
    }, selection);

    // Apply user custom values
    min = nglMinBFactor || min;
    max = nglMaxBFactor || max;
    //console.log("B-FACTOR range (before offset): ", min, max);

    // Update form
    $("#txt-ngl-bfactor-min").val(Math.round(min * 1000) / 10); // round + percentage conversion
    $("#txt-ngl-bfactor-max").val(Math.round(max * 1000) / 10); // round + percentage conversion
    
    if (min < 0) {
      nglBFactorOffset = -min;
      min += nglBFactorOffset;
      max += nglBFactorOffset;
    }
    //console.log("B-FACTOR range (after offset): ", min, max);
    
    // TODO: add input fields
    this.domain = [ min, max ];
    this.scale = gradientColorScale;
    // this.mode = 'rgb';
    
    nglColorScale = chroma
      .scale(this.scale)
      .mode(this.mode)
      .domain(this.domain)
      .out('num');
    
    this.atomColor = function (atom) {
      var color = calcResidueColorforHDX(nglColorScale, atom.resno, atom.bfactor);
      //console.log(color);
      return color;

      /*if (atom.residueIndex == selectedResNumber) newColor = 0x00FF00;
      else if (atom.bfactor == -1) {
        if (nglUndetectedRegionColor == 'black') newColor = 0x000000;
        else if (nglUndetectedRegionColor == 'grey') newColor = 0xAAAAAA;
        else if (nglUndetectedRegionColor == 'white') newColor = 0xFFFFFF;
        else newColor = 0xAAAAAA;
      }
      else {
        var value = atom.bfactor + offset;
        newColor = scale(value);
      }

      return newColor;*/
    }
  });

}

var BACKGROUND_IMAGE;
function init() {

  // Create NGL color scheme
  createNglColorScheme(['blue', 'red']);
  //createNglColorScheme(['blue', 'white', 'red']);

  // Create NGL Stage object
  nglStage = new NGL.Stage( "viewport" );
  
  BACKGROUND_IMAGE = nglStage.makeImage({
    factor: 1,
    antialias: false,
    trim: false,
    transparent: false
  })

  // Change MSA color scheme
  /*nglStage.signals.componentAdded.add( function( component ){
    console.log("component added");
  });*/

  // Handle window resizing
  window.addEventListener( "resize", function( event ) {
    nglStage.handleResize();
  }, false );

  $( "#sel-ngl-repr" ).change(function() {
    changeRepresentation();
  });
  $( "#sel-ngl-color-scale" ).change(function() {
    changeColorScheme();
  });
  $( "#sel-ngl-nodata-color" ).change(function() {
    changeUndetectedRegionColor();
  });
  $( "#sel-ngl-bgcolor" ).change(function() {
    changeBackgroundColor();
  });
  
  // We need to use a MutationObserver to capture CSS changes of the buttons used for custom colors
  let observeColorButtonStyleChange = function(elId,action) {
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutationRecord) {
        $("#sel-ngl-color-scale").val("custom");
        action();
      });
    });

    observer.observe(document.getElementById(elId), { attributes : true, attributeFilter : ['style'] });
  }

  observeColorButtonStyleChange('btn-ngl-min-value-color',changeColorScheme);
  observeColorButtonStyleChange('btn-ngl-max-value-color',changeColorScheme);
  
} // ends function init()

var loaderMaskImages = [
  "./img/loader-mask-black.gif"
];

function addStructure(pdbURL, structName, displayLoader, callbackFn) {

  if (displayLoader) {
    $("#viewport").busyLoad("show", {
      text: "LOADING...",
      image: loaderMaskImages[Math.floor(Math.random()*loaderMaskImages.length)],
      minSize: "150px",
      maxSize: "150px"
    });
  }

  // Load PDB entry 1CRN
  //nglStage.loadFile( "rcsb://1AVO", { defaultRepresentation: false, color: nglColorScheme} ).then( function( o ){
  nglStage.loadFile( pdbURL, { defaultRepresentation: false, color: nglColorScheme} ).then( function( component ) {

    let addRepresentation = function() {

      nglStructByName[structName] = component;
      nglReprByName[structName] = component.addRepresentation( $("#sel-ngl-repr option:selected").val(), { colorScheme: nglColorScheme} );
      
      if (MSA) {
        MSA.g.colorscheme.set("scheme", "hdx");
        MSA.render();
      }

      if (callbackFn) callbackFn(component);
    };

    if (displayLoader) {
      setTimeout(function(){
        $("#viewport").busyLoad("hide");
        addRepresentation();
      },250);
    } else {
      addRepresentation();
    }
    
  });
}

function replaceStructure(pdbFilePath,displayLoader, cb) {
  let pdbFileName = getFileName(pdbFilePath);
  let pdbFileURL = './' + pdbFilePath.split("public/").pop();

  let oldComponent = nglStructByName[pdbFileName];
  if (oldComponent) {
    nglReprByName[pdbFileName] = oldComponent.addRepresentation( $("#sel-ngl-repr option:selected").val(), { colorScheme: nglColorScheme} );
    if (cb) cb(oldComponent);
    return;
  }

  var callbackFn = function(newComponent) {
    if (oldComponent && nglStructByName[pdbFileName]) {
      oldComponent.dispose();
    }
    
    /*for (let structName in nglReprByName) {
      if (structName != pdbFileName) {
        nglReprByName[structName].dispose();
        delete nglReprByName[structName];
      }
    }*/

    if (!displayLoader && cb) cb(newComponent);
  };
  if (displayLoader) {
    callbackFn();
    callbackFn = cb;
  }

  addStructure(pdbFileURL,pdbFileName,displayLoader,callbackFn);
}

// Define some vars for GIF capture
// NEW WAY
//var gif;
//var canvas;

// OLD WAY
/*var gifCapturer;
var oldReqAnimFrameFn = window.requestAnimationFrame;
var iTest = 0;
var gifCapturerCallback = function () {
  if (gifCapturer) {
    iTest++;
    gifCapturer.capture(canvas);
  }
};

window.requestAnimationFrame = function(callback, element) {
  // call the original function
  var result = oldReqAnimFrameFn(callback, element);
  
  gifCapturerCallback();
  
  return result;
};*/
//console.log("oldReqAnimFrameFn",oldReqAnimFrameFn);
//console.log("window.requestAnimationFrame",window.requestAnimationFrame);

var animationIntervalTimerID = -1;
var isAnimated = false;
function toggleStructureAnimation() {
  let delay = $("#txt-ngl-animation-delay").val();
  let loopForever = $('#cbx-ngl-animation-loop').is(":checked");
  
  // NEW WAY
  /*if (!canvas) {
    canvas = document.getElementById("viewport").getElementsByTagName('canvas')[0];
  }*/
  
  // OLD WAY
  // lazy creation of gifCapturer
  /*if (!gifCapturer) {
    gifCapturer = new CCapture({
      format: 'gif',
      workersPath: './js/',
      verbose: true,
      display: false,
      framerate: 1,
      //frameLimit: FRAMELIMIT
      timeLimit: 10
    });
  }*/
  
  isAnimated = !isAnimated;
  if (isAnimated) {
    $("#btn-ngl-animation-ctrl").text('Stop animation');
  } else {
    clearInterval(animationIntervalTimerID);
    animationIntervalTimerID = -1;
    $("#btn-ngl-animation-ctrl").text('Start animation');
    
    // OLD WAY
    /*if (gifCapturer) {
      gifCapturer.stop();

      // default save, will download automatically a file called {name}.extension (webm/gif/tar)
      try {
        gifCapturer.save();
      } catch(error) {
        console.log(error);
      } finally {
        return;
      }
      
    }
    console.log("after gifCapturer");*/
    
    // NEW WAY
    //gif.render();
    
    return;
  }

  if (animationIntervalTimerID != -1) {
    clearInterval(animationIntervalTimerID);
  }
  
  //console.log(lastRespAsJSON);

  if (lastRespAsJSON) {
    let pdbFiles = lastRespAsJSON.pdb_files;
    let pdbFilesCount = pdbFiles.length;
    var pdfFileIdx = 0;
    
    // OLD WAY
    // Capture first frame
    //gifCapturer.capture(canvas);

    animationIntervalTimerID = setInterval(function(){
      if (animationIntervalTimerID == -1) {
        console.log("setInterval was not cancelled properly...");
        return;
      }
      console.log("updating structure for animation...");
      
      replaceStructure(pdbFiles[pdfFileIdx], false, function(newNglComponent) {
        // OLD WAY
        //gifCapturer.capture(canvas);
        //gif.addFrame(canvas, {delay: 500, copy: true}); // canvas.getContext('webgl', {})
        
        // NEW WAY
        // TODO: take delay from config
        /*nglStage.makeImage({
          factor: 1,
          antialias: false,
          trim: false,
          transparent: false
        }).then(function (blob) {
          //console.log(blob);
          //let image = new ImageData(blob, canvas.width, canvas.height);
          var image = new Image();
          image.src = URL.createObjectURL(blob);
          gif.addFrame(image, {delay: 1000, copy: false});
        });*/
        
      });
      
      pdfFileIdx++;

      if (pdfFileIdx == pdbFilesCount) {
        if (loopForever) pdfFileIdx = 0;
        else {
          clearInterval(animationIntervalTimerID);
          isAnimated = false;
          $("#btn-ngl-animation-ctrl").text('Start animation');
        }
      }
    },
    delay
    );
    
    /*if (gifCapturer) {
      gifCapturer.start();
    }*/
    
    // NEW WAY
    /*
    gif = new GIF({
      workers: 2,
      quality: 10,
      workerScript: '/js/gif.worker.js',	//gif.worker.js	url to load worker script from
      //background:	// default = #fff	; background color where source image is transparent
      //background: '#000',
      //transparent: 0x000000,
      //dispose: 2, // reset to background between each frame
      width: canvas.width,	// output image width
      height: canvas.height,	// output image height
      debug: true // whether to print debug information to console
    });

    gif.on('finished', function(blob) {
      window.open(URL.createObjectURL(blob));
    });
    */
  }

}

function switchToFullScreen() {
  nglStage.toggleFullscreen();
  nglFullScreenOn = true;
}

function savePosition() {
  //nglOrientations.push(nglStage.viewerControls.getOrientation());
  nglOrientations[0]  =nglStage.viewerControls.getOrientation();
};

function restorePosition() {
  if (!nglOrientations.length) return;
  nglStage.viewerControls.orient(nglOrientations[0]);
}

/*function replayOrientations(idx) {
  if (!idx) idx = 0;
  if (idx >= nglOrientations.length) {return;}

  nglStage.viewerControls.orient(nglOrientations[idx]);

  setTimeout(
    function(){
      let newIdx = idx + 1;
      replayOrientations(newIdx);
    },
    $("#txt-ngl-orientation-delay").val()
  );
}*/

var isSpinning = false;
var spinAnimation = null;
var lastAngle = null;
function toggleSpinning() {
  let angle = $("#txt-ngl-spinning-angle").val();
  
  //let loopForever = $('#cbx-ngl-spinning-loop').is(":checked");
  
  isSpinning = !isSpinning;
  if (isSpinning) {
    spinAnimation = nglStage.animationControls.spin([ 0, 1, 0 ], angle);
    //spinAnimation.resume(false);
    $("#btn-ngl-spinning-ctrl").text('Stop spinning');
  } else {
    spinAnimation.pause(false);
    $("#btn-ngl-spinning-ctrl").text('Start spinning');
  }
  
  lastAngle = angle;
}

// Define some vars for GIF capture
var gif;
var canvas;

var isRecording = false;
var recordingIntervalTimerID = -1;
function toggleGIFRecording() {
  var delay = isAnimated ? $("#txt-ngl-animation-delay").val() : 500;

  if (!canvas) {
    canvas = document.getElementById("viewport").getElementsByTagName('canvas')[0];
  }

  isRecording = !isRecording;
  if (isRecording) {
    $("#btn-gif-recording-ctrl").text('Stop recording');
    
    //var outputWindow = window.open('', '_blank');
    //outputWindow.blur();
    
    gif = new GIF({
      workers: 2,
      quality: 10,
      workerScript: '/js/gif.worker.js',	//gif.worker.js	url to load worker script from
      //background:	// default = #fff	; background color where source image is transparent
      //background: '#000',
      //transparent: 0x000000,
      //dispose: 2, // reset to background between each frame
      width: canvas.width,	// output image width
      height: canvas.height,	// output image height
      debug: true // whether to print debug information to console
    });

    gif.on('finished', function(blob) {
      var nActiveWorkers = gif.activeWorkers.length;
      if (nActiveWorkers == 0) {
        var outputWindow = window.open(URL.createObjectURL(blob));
        $('#img-gif-recording').hide();
        
        if(!outputWindow || outputWindow.closed || typeof outputWindow.closed=='undefined') { 
          alert("Your GIF has been blocked by your web browser. Try to allow popup for this page.");
        } else {
          outputWindow.focus();
        }
        
        $("#btn-gif-recording-ctrl").fadeTo( 200 , 1);
        $("#btn-gif-recording-ctrl").prop("disabled",false);
        $("#btn-gif-recording-ctrl").text('Record GIF');
      } else {
        console.log("Some GIF rendering workers are still active (n = "+ nActiveWorkers +"), waiting for completion...");
      }
    });
    
    recordingIntervalTimerID = setInterval(function(){
      console.log("adding image to GIF...");
      $("#btn-gif-recording-ctrl").fadeTo( 200 , 0.5, function() {
        // Animation complete.
        $("#btn-gif-recording-ctrl").fadeTo( 200 , 1);
      });
      //.toggle( "fade" ).toggle( "fade" );
      
      var wasSpinning = isSpinning;
      
      if (isSpinning)
        spinAnimation.pause(false);
      
      nglStage.makeImage({
        factor: 1,
        antialias: false,
        trim: false,
        transparent: false
      }).then(function (blob) {
        if (wasSpinning)
          spinAnimation.resume(false);
      
        //console.log(blob);
        //let image = new ImageData(blob, canvas.width, canvas.height);
        var image = new Image();
        image.src = URL.createObjectURL(blob);
        gif.addFrame(image, {delay: 200, copy: false});
      });
    }, 200);
    
  } else {
    clearInterval(recordingIntervalTimerID);
    recordingIntervalTimerID = -1;
    $("#btn-gif-recording-ctrl").text('Rendering GIF...');
    $("#btn-gif-recording-ctrl").prop("disabled",true);
    $("#btn-gif-recording-ctrl").fadeTo( 200 , 0.5, function() {
      $("#btn-gif-recording-ctrl").fadeTo( 200 , 0.5);
    });
    $('#img-gif-recording').show();
    
    console.log("rendering GIF...");
    gif.render();
    
    //alert("Your GIF is being rendered, close this message and wait...");
    
  }
  
}

function changeRepresentation() {
  try {
    let newReprName = $("#sel-ngl-repr option:selected").val();
    
    for (let structName in nglReprByName) {
      let nglStruct = nglStructByName[structName];

      let newRepr = nglStruct.addRepresentation( newReprName, { colorScheme: nglColorScheme} );
      nglReprByName[structName] = newRepr;

      //nglStruct.removeRepresentation(nglReprByName[structName]);
      //nglReprByName[structName].dispose();

      nglStruct.eachRepresentation (function(repr) {
        if (repr != newRepr) {
          nglStruct.removeRepresentation(repr);
        }
      });
    }

  } catch(e) {
    console.log(e);
  }
}

function changeColorScheme() {

  try {
    let selectedColorScale = $("#sel-ngl-color-scale option:selected").val();

    let gradientColorScale = null;
    if (selectedColorScale != "custom") {
      gradientColorScale = selectedColorScale.split('-');
    } else {
      let minValJScolor = document.getElementById('btn-ngl-min-value-color').jscolor.rgb;
      let maxValJScolor = document.getElementById('btn-ngl-max-value-color').jscolor.rgb;
  
      //console.log(document.getElementById('btn-ngl-min-value-color').jscolor);

      gradientColorScale = [minValJScolor, maxValJScolor];
    }

    //console.log("Color scale: ", gradientColorScale);

    createNglColorScheme(gradientColorScale);

    for (let structName in nglReprByName) {
      nglReprByName[structName].setParameters({
        colorScheme: nglColorScheme
      });
    }

    // Refresh MSA colors
    MSA.render();
    
    // TODO: do not change the type of representation
    //changeRepresentation();

  } catch(e) {
    console.log(e);
  }
}

function setBFactorRange() {
  nglMinBFactor = $("#txt-ngl-bfactor-min").val();
  if (nglMinBFactor) nglMinBFactor /= 100;

  nglMaxBFactor = $("#txt-ngl-bfactor-max").val();
  if (nglMaxBFactor) nglMaxBFactor /= 100;

  changeColorScheme();
}

function changeUndetectedRegionColor() {
  try {
    nglUndetectedRegionColor = $("#sel-ngl-nodata-color option:selected").val();
    changeColorScheme();
  } catch(e) {
    console.log(e);
  }
}

function changeBackgroundColor() {

  try {
    let newBgColor = $("#sel-ngl-bgcolor option:selected").val();

    let isChrome = /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor);

    // FIXME: there is a bug in NGL preventing to change the background color in Chrome (see https://github.com/arose/ngl/issues/525)
    // TODO: remove extra ThreeJS dependency when the problem has been solved by NGL devs
    if (isChrome) {

      if (newBgColor == 'black')
        nglStage.viewer.scene.background = new THREE.Color( 0x000000 );
      else if (newBgColor == 'white')
        nglStage.viewer.scene.background = new THREE.Color( 0xffffff );

      nglStage.viewer.requestRender();
    } else {
      nglStage.setParameters({backgroundColor: newBgColor});
    }

  } catch(e) {
    console.log(e);
  }
}

function exportImage() {
  if (!lastRespAsJSON) return;

  let structName = getFileName(lastRespAsJSON.fasta_file).replace('.fasta','');

  let imageExportPromise = nglStage.makeImage({
    factor: 4,
    antialias: true,
    trim: false,
    transparent: true
  })

  let viewport = $("#viewport");
  viewport.busyLoad("show", {
    text: "EXPORTING...",
    image: loaderMaskImages[Math.floor(Math.random()*loaderMaskImages.length)],
    minSize: "150px",
    maxSize: "150px"
  });
  
  imageExportPromise.then(function (blob) {
    NGL.download(blob, structName+'.png');
    viewport.busyLoad("hide");
  })
}

function downloadOutputFiles() {
  if (lastRespAsJSON) {
    $.get( "/download_results", {pdb_files: lastRespAsJSON.pdb_files, fasta_file: lastRespAsJSON.fasta_file} ).done(function(data) {
      let dataURL = './' + data.split("public/").pop();
      window.location.href = dataURL;
    });
  }
}



// --- Sequence Viewer --- //
var MSA = null;

var msaCustomColorScheme = {};

// the init function should be only called once (but it's not waht we observe)
msaCustomColorScheme.init = function() {
  //console.log(this.opt);
  // you have here access to the conservation or the sequence object
  //this.cons = this.opt.conservation();
  //console.log(this.cons);

  if (lastRespAsJSON && nglSelectedPdbFilePath) {
    let pdbFileName = getFileName(nglSelectedPdbFilePath);
    this.structure_bfactor_mapping = lastRespAsJSON.bfactor_mapping[pdbFileName];
  }

  //this.selected_
}

msaCustomColorScheme.run = function(letter,opts){
  //return this.cons[opts.pos] > 0.8 ? "red" : "#fff";
  let chainIndex = opts.y;
  let resNumber = opts.pos;

  //console.log(this.structure_bfactor_mapping);

  if (!this.structure_bfactor_mapping) return "white";

  //console.log(letter,opts);

  let chainData = this.structure_bfactor_mapping[chainIndex];
  if (!chainData) return "white";

  let bfactor = chainData[resNumber + 1];
  bfactor = bfactor == null ? -1 : bfactor;

  return decimalColorToHex(calcResidueColorforHDX(nglColorScale, resNumber + 1, bfactor));

  //return nglColorByResIndex.length ? nglColorByResIndex[resIndex] : "white";
};

function displayFastaFile(fastaURL) {
  
  //console.log(lastRespAsJSON.bfactor_mapping);
  var newMSA = !MSA ? true: false;
  
  if (newMSA) {
    console.log("Instantiating MSA...");
    
    var opts = {
      el: document.getElementById("div-fasta"),
      vis: {
        conserv: false,
        overviewbox: false
      },
      colorscheme: {"scheme": "foo"},
      // smaller menu for JSBin
      menu: "small",
      bootstrapMenu: true,
      conf: {
        importProxy: "" // avoid the CORS proxy use
      }
    };

    MSA = new msa.msa(opts);
    
    // Set custom colors
    MSA.g.colorscheme.addDynScheme("hdx", msaCustomColorScheme);
    
    MSA.g.on("residue:click", function(data){
      selectedResNumber = data.rowPos + 1;
      console.log(data);
      
      for (let structName in nglReprByName) {
        nglReprByName[structName].setColor(nglColorScheme);
        nglReprByName[structName].update({ color: true });
      }
    });
    
    // Customize menu items
    var menuItems = $('#div-fasta').parent().children().first().children();
    
    menuItems.eq(0).hide(); // Hide "Import" menu
    //menuItems.eq(1).hide(); // Hide "Sorting" menu
    menuItems.eq(2).hide(); // Hide "Filter" menu
    
    // Hide some items of the "Selection" menu (Invert Columns / Invert Rows)
    let selMenuItems = menuItems.eq(3).find( "li" );
    selMenuItems.eq(1).hide();
    selMenuItems.eq(2).hide();
    
    // Hide some items of the "Color scheme" menu (Nucleotide / Purine)
    /*let colorSchemeMenuItems = menuItems.eq(5).find( "li" );
    // TODO: remove by name instead of index
    colorSchemeMenuItems.eq(9).first().remove();
    console.log(colorSchemeMenuItems.eq(9));
    colorSchemeMenuItems.eq(10).first().remove();
    console.log(colorSchemeMenuItems.eq(10));
    console.log(colorSchemeMenuItems);*/
    
    // Hide some items of the "Extras" menu (Add consensus seq)
    let extraMenuItems = menuItems.eq(6).find( "li" );
    extraMenuItems.eq(0).hide();
    
  } else {
    MSA.g.colorscheme.set("scheme", "own");
  }
  
  console.log(fastaURL);
  
  //m.u.file.importURL("https://www.uniprot.org/uniprot/Q06323.fasta", function(){
  MSA.u.file.importURL(fastaURL, function(){
    if (newMSA) MSA.render();
    //MSA.g.colorscheme.set("scheme", "hdx");
  });

}