var StaticSchemeClass = function(map){
  this.defaultColor = "#ffffff";
  this.type = "static";
  this.map = map;
  this.getColor = function(letter){
    if(this.map[letter] !== undefined){
      return this.map[letter]; 
    }else{
      return this.defaultColor;
    }
  };
};

var DynSchemeClass = function(fun,opt){
  this.type = "dyn";
  this.opt = opt;
  // init
  if(fun.init !== undefined){
    fun.init.call(this);
    this.getColor = fun.run;
    this.reset = fun.init;
  }else{
    this.getColor = fun;
  }
};

var pid = {};

// calculating the conservation is expensive 
// we only want to do it once
pid.init = function(){
  this.cons = this.opt.conservation();
}

pid.run = function(letter,opts){
  var cons = this.cons[opts.pos];
  if(cons > 0.8){
    return "#6464ff";
  }else if(cons > 0.6){
    return "#9da5ff";
  }else if(cons > 0.4){
    return "#cccccc";
  }else{
    return "#ffffff";
  }
}

var Buried = {
  A: "#00a35c",
  R: "#00fc03",
  N: "#00eb14",
  D: "#00eb14",
  C: "#0000ff",
  Q: "#00f10e",
  E: "#00f10e",
  G: "#009d62",
  H: "#00d52a",
  I: "#0054ab",
  L: "#007b84",
  K: "#00ff00",
  M: "#009768",
  F: "#008778",
  P: "#00e01f",
  S: "#00d52a",
  T: "#00db24",
  W: "#00a857",
  Y: "#00e619",
  V: "#005fa0",
  B: "#00eb14",
  X: "#00b649",
  Z: "#00f10e"
};
var Cinema = {
  A: "#BBBBBB",
  B: "grey",
  C: "yellow",
  D: "red",
  E: "red",
  F: "magenta",
  G: "brown",
  H: "#00FFFF",
  I: "#BBBBBB",
  J: "#fff",
  K: "#00FFFF",
  L: "#BBBBBB",
  M: "#BBBBBB",
  N: "green",
  O: "#fff",
  P: "brown",
  Q: "green",
  R: "#00FFFF",
  S: "green",
  T: "green",
  U: "#fff",
  V: "#BBBBBB",
  W: "magenta",
  X: "grey",
  Y: "magenta",
  Z: "grey",
  Gap: "grey"
};
var Clustal = {
  A: "orange",
  B: "#fff",
  C: "green",
  D: "red",
  E: "red",
  F: "blue",
  G: "orange",
  H: "red",
  I: "green",
  J: "#fff",
  K: "red",
  L: "green",
  M: "green",
  N: "#fff",
  O: "#fff",
  P: "orange",
  Q: "#fff",
  R: "red",
  S: "orange",
  T: "orange",
  U: "#fff",
  V: "green",
  W: "blue",
  X: "#fff",
  Y: "blue",
  Z: "#fff",
  Gap: "#fff"
};
var Clustal2 = {
  A: "#80a0f0",
  R: "#f01505",
  N: "#00ff00",
  D: "#c048c0",
  C: "#f08080",
  Q: "#00ff00",
  E: "#c048c0",
  G: "#f09048",
  H: "#15a4a4",
  I: "#80a0f0",
  L: "#80a0f0",
  K: "#f01505",
  M: "#80a0f0",
  F: "#80a0f0",
  P: "#ffff00",
  S: "#00ff00",
  T: "#00ff00",
  W: "#80a0f0",
  Y: "#15a4a4",
  V: "#80a0f0",
  B: "#fff",
  X: "#fff",
  Z: "#fff"
};
var Helix = {
  A: "#e718e7",
  R: "#6f906f",
  N: "#1be41b",
  D: "#778877",
  C: "#23dc23",
  Q: "#926d92",
  E: "#ff00ff",
  G: "#00ff00",
  H: "#758a75",
  I: "#8a758a",
  L: "#ae51ae",
  K: "#a05fa0",
  M: "#ef10ef",
  F: "#986798",
  P: "#00ff00",
  S: "#36c936",
  T: "#47b847",
  W: "#8a758a",
  Y: "#21de21",
  V: "#857a85",
  B: "#49b649",
  X: "#758a75",
  Z: "#c936c9"
};
var Hydro = {
  A: "#ad0052",
  B: "#0c00f3",
  C: "#c2003d",
  D: "#0c00f3",
  E: "#0c00f3",
  F: "#cb0034",
  G: "#6a0095",
  H: "#1500ea",
  I: "#ff0000",
  J: "#fff",
  K: "#0000ff",
  L: "#ea0015",
  M: "#b0004f",
  N: "#0c00f3",
  O: "#fff",
  P: "#4600b9",
  Q: "#0c00f3",
  R: "#0000ff",
  S: "#5e00a1",
  T: "#61009e",
  U: "#fff",
  V: "#f60009",
  W: "#5b00a4",
  X: "#680097",
  Y: "#4f00b0",
  Z: "#0c00f3"
};
var Lesk = {
  A: " orange",
  B: " #fff",
  C: " green",
  D: " red",
  E: " red",
  F: " green",
  G: " orange",
  H: " magenta",
  I: " green",
  J: " #fff",
  K: " red",
  L: " green",
  M: " green",
  N: " magenta",
  O: " #fff",
  P: " green",
  Q: " magenta",
  R: " red",
  S: " orange",
  T: " orange",
  U: " #fff",
  V: " green",
  W: " green",
  X: " #fff",
  Y: " green",
  Z: " #fff",
  Gap: " #fff"
};
var Mae = {
  A: " #77dd88",
  B: " #fff",
  C: " #99ee66",
  D: " #55bb33",
  E: " #55bb33",
  F: " #9999ff",
  G: " #77dd88",
  H: " #5555ff",
  I: " #66bbff",
  J: " #fff",
  K: " #ffcc77",
  L: " #66bbff",
  M: " #66bbff",
  N: " #55bb33",
  O: " #fff",
  P: " #eeaaaa",
  Q: " #55bb33",
  R: " #ffcc77",
  S: " #ff4455",
  T: " #ff4455",
  U: " #fff",
  V: " #66bbff",
  W: " #9999ff",
  X: " #fff",
  Y: " #9999ff",
  Z: " #fff",
  Gap: " #fff"
};
var Nucleotide = {
  A: " #64F73F",
  C: " #FFB340",
  G: " #EB413C",
  T: " #3C88EE",
  U: " #3C88EE"
};

var Purine = {
  A: " #FF83FA",
  C: " #40E0D0",
  G: " #FF83FA",
  R: " #FF83FA",
  T: " #40E0D0",
  U: " #40E0D0",
  Y: " #40E0D0"
};
var Strand = {
  A: "#5858a7",
  R: "#6b6b94",
  N: "#64649b",
  D: "#2121de",
  C: "#9d9d62",
  Q: "#8c8c73",
  E: "#0000ff",
  G: "#4949b6",
  H: "#60609f",
  I: "#ecec13",
  L: "#b2b24d",
  K: "#4747b8",
  M: "#82827d",
  F: "#c2c23d",
  P: "#2323dc",
  S: "#4949b6",
  T: "#9d9d62",
  W: "#c0c03f",
  Y: "#d3d32c",
  V: "#ffff00",
  B: "#4343bc",
  X: "#797986",
  Z: "#4747b8"
};
var Taylor = {
  A: "#ccff00",
  R: "#0000ff",
  N: "#cc00ff",
  D: "#ff0000",
  C: "#ffff00",
  Q: "#ff00cc",
  E: "#ff0066",
  G: "#ff9900",
  H: "#0066ff",
  I: "#66ff00",
  L: "#33ff00",
  K: "#6600ff",
  M: "#00ff00",
  F: "#00ff66",
  P: "#ffcc00",
  S: "#ff3300",
  T: "#ff6600",
  W: "#00ccff",
  Y: "#00ffcc",
  V: "#99ff00",
  B: "#fff",
  X: "#fff",
  Z: "#fff"
};
var Turn = {
  A: "#2cd3d3",
  R: "#708f8f",
  N: "#ff0000",
  D: "#e81717",
  C: "#a85757",
  Q: "#3fc0c0",
  E: "#778888",
  G: "#ff0000",
  H: "#708f8f",
  I: "#00ffff",
  L: "#1ce3e3",
  K: "#7e8181",
  M: "#1ee1e1",
  F: "#1ee1e1",
  P: "#f60909",
  S: "#e11e1e",
  T: "#738c8c",
  W: "#738c8c",
  Y: "#9d6262",
  V: "#07f8f8",
  B: "#f30c0c",
  X: "#7c8383",
  Z: "#5ba4a4"
};
var Zappo = {
  A: "#ffafaf",
  R: "#6464ff",
  N: "#00ff00",
  D: "#ff0000",
  C: "#ffff00",
  Q: "#00ff00",
  E: "#ff0000",
  G: "#ff00ff",
  H: "#6464ff",
  I: "#ffafaf",
  L: "#ffafaf",
  K: "#6464ff",
  M: "#ffafaf",
  F: "#ffc800",
  P: "#ff00ff",
  S: "#00ff00",
  T: "#00ff00",
  W: "#ffc800",
  Y: "#ffc800",
  V: "#ffafaf",
  B: "#fff",
  X: "#fff",
  Z: "#fff"
};

var staticSchemes = {
  buried: Buried,
  buried_index: Buried,
  cinema: Cinema,
  clustal2: Clustal2,
  clustal: Clustal,
  helix: Helix,
  helix_propensity: Helix,
  hydro: Hydro,
  lesk: Lesk,
  mae: Mae,
  nucleotide: Nucleotide,
  purine: Purine,
  purine_pyrimidine: Purine,
  strand: Strand,
  strand_propensity: Strand,
  taylor: Taylor,
  turn: Turn,
  turn_propensity: Turn,
  zappo: Zappo
};

var dynSchemes = {
  pid: pid
};

var MSAColorsSchemes = function(opt){
  this.maps = _cloneObj(staticSchemes);  
  this.dyn = _cloneObj(dynSchemes);
  this.opt = opt;
}
MSAColorsSchemes.getScheme = function(scheme){
  return staticSchemes[scheme];
}
MSAColorsSchemes.prototype.getScheme = function(scheme) {
  var color = this.maps[scheme];
  if (color === undefined) {
    color = {};
    if(this.dyn[scheme] != undefined){
      return new DynSchemeClass(this.dyn[scheme],this.opt);
    }
  }
  return new StaticSchemeClass(color);
};

MSAColorsSchemes.prototype.addStaticScheme = function(name,scheme) {
  this.maps[name] = scheme;
}

MSAColorsSchemes.prototype.addDynScheme = function(name,scheme) {
  this.dyn[name] = scheme;
}

// small helper to clone an object
function _cloneObj(obj) {
  if (null == obj || "object" != typeof obj) return obj;
  var copy = obj.constructor();
  for (var attr in obj) {
    if (obj.hasOwnProperty(attr)) copy[attr] = obj[attr];
  }
  return copy;
}
