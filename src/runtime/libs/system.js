rtl.module("system",[],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  var $lt = null;
  var $lt1 = null;
  var $lt2 = null;
  var $lt3 = null;
  var $lt4 = null;
  var $lt5 = null;
  var $lt6 = null;
  var $lt7 = null;
  var $lt8 = null;
  var $lt9 = null;
  var $lt10 = null;
  var $lt11 = null;
  var $lt12 = null;
  var $lt13 = null;
  var $lt14 = null;
  var $lt15 = null;
  var $lt16 = null;
  var $lt17 = null;
  this.lineending = "\n";
  this.slinebreak = "\n";
  this.pathdelim = "\/";
  this.$rtti.$Set("AllowDirectorySeparators$a",{comptype: rtl.char});
  this.allowdirectoryseparators = rtl.createSet(47);
  this.$rtti.$Set("AllowDriveSeparators$a",{comptype: rtl.char});
  this.allowdriveseparators = rtl.createSet(58);
  this.extensionseparator = ".";
  this.maxsmallint = 32767;
  this.minsmallint = -32768;
  this.maxshortint = 127;
  this.minshortint = -128;
  this.maxbyte = 0xFF;
  this.maxword = 0xFFFF;
  this.maxlongint = 0x7fffffff;
  this.maxcardinal = 0xffffffff;
  this.maxint = 2147483647;
  this.ismultithread = false;
  this.$rtti.$inherited("Real",rtl.double,{});
  this.$rtti.$inherited("Extended",rtl.double,{});
  this.$rtti.$inherited("TDateTime",rtl.double,{});
  this.$rtti.$inherited("TTime",this.$rtti["TDateTime"],{});
  this.$rtti.$inherited("TDate",this.$rtti["TDateTime"],{});
  this.$rtti.$inherited("Int64",rtl.nativeint,{});
  this.$rtti.$inherited("UInt64",rtl.nativeuint,{});
  this.$rtti.$inherited("QWord",rtl.nativeuint,{});
  this.$rtti.$inherited("Single",rtl.double,{});
  this.$rtti.$inherited("Comp",rtl.nativeint,{});
  this.$rtti.$inherited("UnicodeString",rtl.string,{});
  this.$rtti.$inherited("WideString",rtl.string,{});
  $lt = this.ttextlinebreakstyle = {"0": "tlbslf", tlbslf: 0, "1": "tlbscrlf", tlbscrlf: 1, "2": "tlbscr", tlbscr: 2};
  this.$rtti.$Enum("TTextLineBreakStyle",{minvalue: 0, maxvalue: 2, ordtype: 1, enumtype: this.ttextlinebreakstyle});
  $lt1 = this.tcompareoption = {"0": "coignorecase", coignorecase: 0};
  this.$rtti.$Enum("TCompareOption",{minvalue: 0, maxvalue: 0, ordtype: 1, enumtype: this.tcompareoption});
  this.$rtti.$Set("TCompareOptions",{comptype: this.$rtti["TCompareOption"]});
  rtl.recNewT(this,"tguid",function () {
    $lt2 = this;
    this.d1 = 0;
    this.d2 = 0;
    this.d3 = 0;
    this.$new = function () {
      var r = Object.create(this);
      r.d4 = rtl.arraySetLength(null,0,8);
      return r;
    };
    this.$eq = function (b) {
      return (this.d1 === b.d1) && (this.d2 === b.d2) && (this.d3 === b.d3) && rtl.arrayEq(this.d4,b.d4);
    };
    this.$assign = function (s) {
      this.d1 = s.d1;
      this.d2 = s.d2;
      this.d3 = s.d3;
      this.d4 = s.d4.slice(0);
      return this;
    };
    var $r = $mod.$rtti.$Record("TGuid",{});
    $r.addField("d1",rtl.longword);
    $r.addField("d2",rtl.word);
    $r.addField("d3",rtl.word);
    $mod.$rtti.$StaticArray("TGuid.D4$a",{dims: [8], eltype: rtl.byte});
    $r.addField("d4",$mod.$rtti["TGuid.D4$a"]);
  });
  this.$rtti.$inherited("TGUIDString",rtl.string,{});
  this.$rtti.$inherited("PMethod",{comptype: this.$rtti["TMethod"]});
  rtl.recNewT(this,"tmethod",function () {
    $lt3 = this;
    this.code = null;
    this.data = null;
    this.$eq = function (b) {
      return (this.code === b.code) && (this.data === b.data);
    };
    this.$assign = function (s) {
      this.code = s.code;
      this.data = s.data;
      return this;
    };
    var $r = $mod.$rtti.$Record("TMethod",{});
    $r.addField("code",rtl.pointer);
    $r.addField("data",rtl.pointer);
  });
  this.$rtti.$Class("TObject");
  this.$rtti.$ClassRef("TClass",{instancetype: this.$rtti["TObject"]});
  rtl.createClass(this,"tobject",null,function () {
    $lt4 = this;
    this.$init = function () {
    };
    this.$final = function () {
    };
    this.create = function () {
      return this;
    };
    rtl.tObjectDestroy = "destroy";
    this.destroy = function () {
    };
    this.free = function () {
      this.$destroy("destroy");
    };
    this.classtype = function () {
      return this;
    };
    this.classnameis = function (name) {
      var Result = false;
      Result = $impl.sametext(name,this.$classname);
      return Result;
    };
    this.inheritsfrom = function (aclass) {
      return (aClass!=null) && ((this==aClass) || aClass.isPrototypeOf(this));
    };
    this.methodname = function (acode) {
      var Result = "";
      Result = "";
      if (acode === null) return Result;
      if (typeof(aCode)!=='function') return "";
      var i = 0;
      var TI = this.$rtti;
      if (rtl.isObject(aCode.scope)){
        // callback
        if (typeof aCode.fn === "string") return aCode.fn;
        aCode = aCode.fn;
      }
      // Not a callback, check rtti
      while ((Result === "") && (TI != null)) {
        i = 0;
        while ((Result === "") && (i < TI.methods.length)) {
          if (this[TI.getMethod(i).name] === aCode)
            Result=TI.getMethod(i).name;
          i += 1;
        };
        if (Result === "") TI = TI.ancestor;
      };
      // return Result;
      return Result;
    };
    this.methodaddress = function (aname) {
      var Result = null;
      Result = null;
      if (aname === "") return Result;
      var i = 0;
        var TI = this.$rtti;
        var N = "";
        var MN = "";
        N = aName.toLowerCase();
        while ((MN === "") && (TI != null)) {
          i = 0;
          while ((MN === "") && (i < TI.methods.length)) {
            if (TI.getMethod(i).name.toLowerCase() === N) MN = TI.getMethod(i).name;
            i += 1;
          };
          if (MN === "") TI = TI.ancestor;
        };
        if (MN !== "") Result = this[MN];
      //  return Result;
      return Result;
    };
    this.fieldaddress = function (aname) {
      var Result = null;
      Result = null;
      if (aname === "") return Result;
      var aClass = null;
      var i = 0;
      var ClassTI = null;
      var myName = aName.toLowerCase();
      var MemberTI = null;
      aClass = this.$class;
      while (aClass !== null) {
        ClassTI = aClass.$rtti;
        for (var $l1 = 0, $end2 = ClassTI.fields.length - 1; $l1 <= $end2; $l1++) {
          i = $l1;
          MemberTI = ClassTI.getField(i);
          if (MemberTI.name.toLowerCase() === myName) {
             return MemberTI;
          };
        };
        aClass = aClass.$ancestor ? aClass.$ancestor : null;
      };
      return Result;
    };
    this.classinfo = function () {
      var Result = null;
      Result = this.$rtti;
      return Result;
    };
    this.afterconstruction = function () {
    };
    this.beforedestruction = function () {
    };
    this.dispatch = function (amessage) {
      var aclass = null;
      var id = undefined;
      if (!rtl.isObject(amessage)) return;
      id = amessage["Msg"];
      if (!rtl.isNumber(id)) return;
      aclass = this.$class.classtype();
      while (aclass !== null) {
        var Handlers = aClass.$msgint;
        if (rtl.isObject(Handlers) && Handlers.hasOwnProperty(Id)){
          this[Handlers[Id]](aMessage);
          return;
        };
        aclass = aclass.$ancestor;
      };
      this.defaulthandler(amessage);
    };
    this.dispatchstr = function (amessage) {
      var aclass = null;
      var id = undefined;
      if (!rtl.isObject(amessage)) return;
      id = amessage["MsgStr"];
      if (!rtl.isString(id)) return;
      aclass = this.$class.classtype();
      while (aclass !== null) {
        var Handlers = aClass.$msgstr;
        if (rtl.isObject(Handlers) && Handlers.hasOwnProperty(Id)){
          this[Handlers[Id]](aMessage);
          return;
        };
        aclass = aclass.$ancestor;
      };
      this.defaulthandlerstr(amessage);
    };
    this.defaulthandler = function (amessage) {
      if (amessage) ;
    };
    this.defaulthandlerstr = function (amessage) {
      if (amessage) ;
    };
    this.getinterface = function (iid, obj) {
      var Result = false;
      var i = iid.$intf;
      if (i){
        // iid is the private TGuid of an interface
        i = rtl.getIntfG(this,i.$guid,2);
        if (i){
          obj.set(i);
          return true;
        }
      };
      Result = this.getinterfacebystr(rtl.guidrToStr(iid),obj);
      return Result;
    };
    this.getinterface$1 = function (iidstr, obj) {
      var Result = false;
      Result = this.getinterfacebystr(iidstr,obj);
      return Result;
    };
    this.getinterfacebystr = function (iidstr, obj) {
      var Result = false;
      Result = false;
      if (!$mod.iobjectinstance["$str"]) $mod.iobjectinstance["$str"] = rtl.guidrToStr($mod.iobjectinstance);
      if (iidstr == $mod.iobjectinstance["$str"]) {
        obj.set(this);
        return true;
      };
      var i = rtl.getIntfG(this,iidstr,2);
      obj.set(i);
      Result=(i!==null);
      return Result;
    };
    this.getinterfaceweak = function (iid, obj) {
      var Result = false;
      Result = this.getinterface(iid,obj);
      if (Result){
        var o = obj.get();
        if (o.$kind==='com'){
          o._Release();
        }
      };
      return Result;
    };
    this.equals = function (obj) {
      var Result = false;
      Result = obj === this;
      return Result;
    };
    this.tostring = function () {
      var Result = "";
      Result = this.$classname;
      return Result;
    };
  });
  rtl.createClass(this,"tcustomattribute",$lt4,function () {
    $lt5 = this;
  });
  this.$rtti.$DynArray("TCustomAttributeArray",{eltype: this.$rtti["TCustomAttribute"]});
  this.s_ok = 0;
  this.s_false = 1;
  this.e_nointerface = -2147467262;
  this.e_unexpected = -2147418113;
  this.e_notimpl = -2147467263;
  rtl.createInterface(this,"iunknown","{00000000-0000-0000-C000-000000000046}",["queryinterface","_addref","_release"],null,function () {
    $lt6 = this;
    this.$kind = "com";
    var $r = this.$rtti;
    $r.addMethod("queryinterface",1,[["iid",$mod.$rtti["TGuid"],2],["obj",null,4]],rtl.longint);
    $r.addMethod("_addref",1,null,rtl.longint);
    $r.addMethod("_release",1,null,rtl.longint);
  });
  rtl.createInterface(this,"iinvokable","{88387EF6-BCEE-3E17-9E85-5D491ED4FC10}",[],$lt6,function () {
    $lt7 = this;
  });
  rtl.createInterface(this,"ienumerator","{ECEC7568-4E50-30C9-A2F0-439342DE2ADB}",["getcurrent","movenext","reset"],$lt6,function () {
    $lt8 = this;
    var $r = this.$rtti;
    $r.addMethod("getcurrent",1,null,$mod.$rtti["TObject"]);
    $r.addMethod("movenext",1,null,rtl.boolean);
    $r.addMethod("reset",0,null);
    $r.addProperty("current",1,$mod.$rtti["TObject"],"getcurrent","");
  });
  rtl.createInterface(this,"ienumerable","{9791C368-4E51-3424-A3CE-D4911D54F385}",["getenumerator"],$lt6,function () {
    $lt9 = this;
    var $r = this.$rtti;
    $r.addMethod("getenumerator",1,null,$mod.$rtti["IEnumerator"]);
  });
  rtl.createClass(this,"tinterfacedobject",$lt4,function () {
    $lt10 = this;
    this.$init = function () {
      $lt4.$init.call(this);
      this.frefcount = 0;
    };
    this.queryinterface = function (iid, obj) {
      var Result = 0;
      if (this.getinterface(iid,obj)) {
        Result = 0}
       else Result = -2147467262;
      return Result;
    };
    this._addref = function () {
      var Result = 0;
      this.frefcount += 1;
      Result = this.frefcount;
      return Result;
    };
    this._release = function () {
      var Result = 0;
      this.frefcount -= 1;
      Result = this.frefcount;
      if (this.frefcount === 0) this.$destroy("destroy");
      return Result;
    };
    this.beforedestruction = function () {
      if (this.frefcount !== 0) rtl.raiseE('EHeapMemoryError');
    };
    rtl.addIntf(this,$lt6);
  });
  this.$rtti.$ClassRef("TInterfacedClass",{instancetype: this.$rtti["TInterfacedObject"]});
  rtl.createClass(this,"taggregatedobject",$lt4,function () {
    $lt11 = this;
    this.$init = function () {
      $lt4.$init.call(this);
      this.fcontroller = null;
    };
    this.getcontroller = function () {
      var Result = null;
      var $ok = false;
      try {
        Result = rtl.setIntfL(Result,this.fcontroller);
        $ok = true;
      } finally {
        if (!$ok) rtl._Release(Result);
      };
      return Result;
    };
    this.queryinterface = function (iid, obj) {
      var Result = 0;
      Result = this.fcontroller.queryinterface(iid,obj);
      return Result;
    };
    this._addref = function () {
      var Result = 0;
      Result = this.fcontroller._addref();
      return Result;
    };
    this._release = function () {
      var Result = 0;
      Result = this.fcontroller._release();
      return Result;
    };
    this.create$1 = function (acontroller) {
      $lt4.create.call(this);
      this.fcontroller = acontroller;
      return this;
    };
  });
  rtl.createClass(this,"tcontainedobject",$lt11,function () {
    $lt12 = this;
    this.queryinterface = function (iid, obj) {
      var Result = 0;
      if (this.getinterface(iid,obj)) {
        Result = 0}
       else Result = -2147467262;
      return Result;
    };
    rtl.addIntf(this,$lt6);
  });
  this.iobjectinstance = $lt2.$clone({d1: 0xD91C9AF4, d2: 0x3C93, d3: 0x420F, d4: [0xA3,0x03,0xBF,0x5B,0xA8,0x2B,0xFD,0x23]});
  $lt13 = this.ttypekind = {"0": "tkunknown", tkunknown: 0, "1": "tkinteger", tkinteger: 1, "2": "tkchar", tkchar: 2, "3": "tkstring", tkstring: 3, "4": "tkenumeration", tkenumeration: 4, "5": "tkset", tkset: 5, "6": "tkdouble", tkdouble: 6, "7": "tkbool", tkbool: 7, "8": "tkprocvar", tkprocvar: 8, "9": "tkmethod", tkmethod: 9, "10": "tkarray", tkarray: 10, "11": "tkdynarray", tkdynarray: 11, "12": "tkrecord", tkrecord: 12, "13": "tkclass", tkclass: 13, "14": "tkclassref", tkclassref: 14, "15": "tkpointer", tkpointer: 15, "16": "tkjsvalue", tkjsvalue: 16, "17": "tkreftoprocvar", tkreftoprocvar: 17, "18": "tkinterface", tkinterface: 18, "19": "tkhelper", tkhelper: 19, "20": "tkextclass", tkextclass: 20};
  this.$rtti.$Enum("TTypeKind",{minvalue: 0, maxvalue: 20, ordtype: 1, enumtype: this.ttypekind});
  this.$rtti.$Set("TTypeKinds",{comptype: this.$rtti["TTypeKind"]});
  this.tkfloat = 6;
  this.tkprocedure = 8;
  this.tkany = rtl.createSet(null,$lt13.tkunknown,$lt13.tkextclass);
  this.tkmethods = rtl.createSet(9);
  this.tkproperties = rtl.diffSet(rtl.diffSet(this.tkany,this.tkmethods),rtl.createSet(0));
  this.vtinteger = 0;
  this.vtboolean = 1;
  this.vtextended = 3;
  this.vtpointer = 5;
  this.vtobject = 7;
  this.vtclass = 8;
  this.vtwidechar = 9;
  this.vtcurrency = 12;
  this.vtinterface = 14;
  this.vtunicodestring = 18;
  this.vtnativeint = 19;
  this.vtjsvalue = 20;
  this.$rtti.$inherited("PVarRec",{comptype: this.$rtti["TVarRec"]});
  rtl.recNewT(this,"tvarrec",function () {
    $lt14 = this;
    this.vtype = 0;
    this.vjsvalue = undefined;
    this.$eq = function (b) {
      return (this.vtype === b.vtype) && (this.vjsvalue === b.vjsvalue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue) && (this.VJSValue === b.VJSValue);
    };
    this.$assign = function (s) {
      this.vtype = s.vtype;
      this.vjsvalue = s.vjsvalue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      this.VJSValue = s.VJSValue;
      return this;
    };
    var $r = $mod.$rtti.$Record("TVarRec",{});
    $r.addField("vtype",rtl.byte);
    $r.addField("vjsvalue",rtl.jsvalue);
    $r.addField("VJSValue",rtl.longint);
    $r.addField("VJSValue",rtl.boolean);
    $r.addField("VJSValue",rtl.double);
    $r.addField("VJSValue",rtl.pointer);
    $r.addField("VJSValue",$mod.$rtti["TObject"]);
    $r.addField("VJSValue",$mod.$rtti["TClass"]);
    $r.addField("VJSValue",rtl.char);
    $r.addField("VJSValue",rtl.nativeint);
    $r.addField("VJSValue",rtl.pointer);
    $r.addField("VJSValue",$mod.$rtti["UnicodeString"]);
    $r.addField("VJSValue",rtl.nativeint);
  });
  this.$rtti.$DynArray("TVarRecArray",{eltype: this.$rtti["TVarRec"]});
  this.varrecs = function () {
    var Result = [];
    var i = 0;
    var v = null;
    Result = [];
    while (i < arguments.length) {
      v = $lt14.$new();
      v.vtype = rtl.trunc(arguments[i]);
      i += 1;
      v.vjsvalue = arguments[i];
      i += 1;
      Result.push($lt14.$clone(v));
    };
    return Result;
  };
  this.isconsole = true;
  this.firstdotatfilenamestartisextension = false;
  this.$rtti.$ProcVar("TOnParamCount",{procsig: rtl.newTIProcSig(null,rtl.longint)});
  this.$rtti.$ProcVar("TOnParamStr",{procsig: rtl.newTIProcSig([["index",rtl.longint]],rtl.string)});
  this.onparamcount = null;
  this.onparamstr = null;
  this.paramcount = function () {
    var Result = 0;
    if ($mod.onparamcount != null) {
      Result = $mod.onparamcount()}
     else Result = 0;
    return Result;
  };
  this.paramstr = function (index) {
    var Result = "";
    if ($mod.onparamstr != null) {
      Result = $mod.onparamstr(index)}
     else if (index === 0) {
      Result = "js"}
     else Result = "";
    return Result;
  };
  this.frac = function (a) {
    return A % 1;
  };
  this.odd = function (a) {
    return A&1 != 0;
  };
  this.random = function (range) {
    return Math.floor(Math.random()*Range);
  };
  this.sqr = function (a) {
    return A*A;
  };
  this.sqr$1 = function (a) {
    return A*A;
  };
  this.trunc = function (a) {
    if (!Math.trunc) {
      Math.trunc = function(v) {
        v = +v;
        if (!isFinite(v)) return v;
        return (v - v % 1) || (v < 0 ? -0 : v === 0 ? v : 0);
      };
    }
    $mod.Trunc = Math.trunc;
    return Math.trunc(A);
  };
  this.defaulttextlinebreakstyle = 0;
  this.int = function (a) {
    var Result = 0.0;
    Result = $mod.trunc(a);
    return Result;
  };
  this.copy = function (s, index, size) {
    if (Index<1) Index = 1;
    return (Size>0) ? S.substring(Index-1,Index+Size-1) : "";
  };
  this.copy$1 = function (s, index) {
    if (Index<1) Index = 1;
    return S.substr(Index-1);
  };
  this.Delete = function (s, index, size) {
    var h = "";
    if ((index < 1) || (index > s.get().length) || (size <= 0)) return;
    h = s.get();
    s.set($mod.copy(h,1,index - 1) + $mod.copy$1(h,index + size));
  };
  this.pos = function (search, instring) {
    return InString.indexOf(Search)+1;
  };
  this.pos$1 = function (search, instring, startat) {
    return InString.indexOf(Search,StartAt-1)+1;
  };
  this.insert = function (insertion, target, index) {
    var t = "";
    if (insertion === "") return;
    t = target.get();
    if (index < 1) {
      target.set(insertion + t)}
     else if (index > t.length) {
      target.set(t + insertion)}
     else target.set($mod.copy(t,1,index - 1) + insertion + $mod.copy(t,index,t.length));
  };
  this.upcase = function (c) {
    return c.toUpperCase();
  };
  this.binstr = function (val, cnt) {
    var Result = "";
    var i = 0;
    Result = rtl.strSetLength(Result,cnt);
    for (var $l = cnt; $l >= 1; $l--) {
      i = $l;
      Result = rtl.setCharAt(Result,i - 1,String.fromCharCode(48 + (val & 1)));
      val = Math.floor(val / 2);
    };
    return Result;
  };
  this.val = function (s, ni, code) {
    ni.set($impl.valint(s,-9007199254740991,9007199254740991,code));
  };
  this.val$1 = function (s, ni, code) {
    var x = 0.0;
    x = Number(s);
    if (isNaN(x) || (x !== $mod.int(x)) || (x < 0)) {
      code.set(1)}
     else {
      code.set(0);
      ni.set($mod.trunc(x));
    };
  };
  this.val$2 = function (s, si, code) {
    si.set($impl.valint(s,-128,127,code));
  };
  this.val$3 = function (s, b, code) {
    b.set($impl.valint(s,0,255,code));
  };
  this.val$4 = function (s, si, code) {
    si.set($impl.valint(s,-32768,32767,code));
  };
  this.val$5 = function (s, w, code) {
    w.set($impl.valint(s,0,65535,code));
  };
  this.val$6 = function (s, i, code) {
    i.set($impl.valint(s,-2147483648,2147483647,code));
  };
  this.val$7 = function (s, c, code) {
    c.set($impl.valint(s,0,4294967295,code));
  };
  this.val$8 = function (s, d, code) {
    var x = 0.0;
    x = Number(s);
    if (isNaN(x)) {
      code.set(1)}
     else {
      code.set(0);
      d.set(x);
    };
  };
  this.val$9 = function (s, b, code) {
    if ($impl.sametext(s,"true")) {
      code.set(0);
      b.set(true);
    } else if ($impl.sametext(s,"false")) {
      code.set(0);
      b.set(false);
    } else code.set(1);
  };
  this.stringofchar = function (c, l) {
    var Result = "";
    var i = 0;
    if ((l>0) && c.repeat) return c.repeat(l);
    Result = "";
    for (var $l = 1, $end = l; $l <= $end; $l++) {
      i = $l;
      Result = Result + c;
    };
    return Result;
  };
  this.write = function () {
    var i = 0;
    for (var $l = 0, $end = arguments.length - 1; $l <= $end; $l++) {
      i = $l;
      if ($impl.writecallback != null) {
        $impl.writecallback(arguments[i],false)}
       else $impl.writebuf = $impl.writebuf + ("" + arguments[i]);
    };
  };
  this.writeln = function () {
    var i = 0;
    var l = 0;
    var s = "";
    l = arguments.length - 1;
    if ($impl.writecallback != null) {
      for (var $l = 0, $end = l; $l <= $end; $l++) {
        i = $l;
        $impl.writecallback(arguments[i],i === l);
      };
    } else {
      s = $impl.writebuf;
      for (var $l1 = 0, $end1 = l; $l1 <= $end1; $l1++) {
        i = $l1;
        s = s + ("" + arguments[i]);
      };
      console.log(s);
      $impl.writebuf = "";
    };
  };
  this.$rtti.$ProcVar("TConsoleHandler",{procsig: rtl.newTIProcSig([["s",rtl.jsvalue],["newline",rtl.boolean]])});
  this.setwritecallback = function (h) {
    var Result = null;
    Result = $impl.writecallback;
    $impl.writecallback = h;
    return Result;
  };
  this.assigned = function (v) {
    return (V!=undefined) && (V!=null) && (!rtl.isArray(V) || (V.length > 0));
  };
  this.strictequal = function (a, b) {
    return A === B;
  };
  this.strictinequal = function (a, b) {
    return A !== B;
  };
  $mod.$implcode = function () {
    $impl.sametext = function (s1, s2) {
      return s1.toLowerCase() == s2.toLowerCase();
    };
    $impl.writebuf = "";
    $impl.writecallback = null;
    $impl.valint = function (s, minval, maxval, code) {
      var Result = 0;
      var x = 0.0;
      x = Number(s);
      if (isNaN(x)) {
        var $tmp = $mod.copy(s,1,1);
        if ($tmp === "$") {
          x = Number("0x" + $mod.copy$1(s,2))}
         else if ($tmp === "&") {
          x = Number("0o" + $mod.copy$1(s,2))}
         else if ($tmp === "%") {
          x = Number("0b" + $mod.copy$1(s,2))}
         else {
          code.set(1);
          return Result;
        };
      };
      if (isNaN(x) || (x !== $mod.int(x))) {
        code.set(1)}
       else if ((x < minval) || (x > maxval)) {
        code.set(2)}
       else {
        Result = $mod.trunc(x);
        code.set(0);
      };
      return Result;
    };
  };
  $mod.$init = function () {
    rtl.exitcode = 0;
  };
},[]);
rtl.run();
