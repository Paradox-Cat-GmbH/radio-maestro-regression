#!/usr/bin/env node
const http=require('http');const{spawn}=require('child_process');const fs=require('fs');const path=require('path');
const REPO=path.resolve(__dirname,'..','..');const ADB=process.env.ADB_BAT||path.join(REPO,'scripts','adb.bat');
const HOST=process.env.MAESTRO_CONTROL_HOST||'127.0.0.1';const PORT=parseInt(process.env.MAESTRO_CONTROL_PORT||'4567',10);

const DEFAULT_RADIO_PKG='com.bmwgroup.apinext.tunermediaservice';
const DEFAULT_SESSION_PKGS=[DEFAULT_RADIO_PKG,'com.bmwgroup.apinext.mediaapp','com.bmwgroup.idnext.vehiclemediacontrol.service','com.bmwgroup.apinext.onboardmediacontroller'];
const SWAG={up:1024,down:1028,left:1016,right:1020,center:1034,menu:1066,media:1014,phone:1054,ptt:1012};

const stamp=()=>{const d=new Date(),p=n=>String(n).padStart(2,'0');return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;}
const mkdir=d=>{try{fs.mkdirSync(d,{recursive:true});}catch(_){}}
const write=(d,f,c)=>{try{mkdir(d);fs.writeFileSync(path.join(d,f),c,'utf8');}catch(_){}}
const jres=(res,code,obj)=>{res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET,POST,OPTIONS','Access-Control-Allow-Headers':'Content-Type'});res.end(JSON.stringify(obj,null,2));}
const readJson=req=>new Promise((ok,fail)=>{let b='';req.on('data',c=>b+=c.toString('utf8'));req.on('end',()=>{if(!b.trim())return ok({});try{ok(JSON.parse(b));}catch(e){fail(e);}});});
const adbArgs=(dev,rest)=>dev?['-s',dev,...rest]:rest;
const run=(args,timeout=25000)=>new Promise(ok=>{const isWin=process.platform==='win32';const cmd=isWin?'cmd.exe':ADB;const cmdArgs=isWin?['/c',ADB,...args]:args;const ch=spawn(cmd,cmdArgs,{cwd:REPO,windowsHide:true});
let out='',err='';const t=setTimeout(()=>{try{ch.kill('SIGKILL');}catch(_){}},timeout);
ch.stdout.on('data',d=>out+=d.toString());ch.stderr.on('data',d=>err+=d.toString());
ch.on('close',code=>{clearTimeout(t);ok({code:code??0,stdout:out,stderr:err});});});
const step=(name,r)=>({name,code:r.code??0,stdout:r.stdout||'',stderr:r.stderr||''});
const outDir=(p,st,id)=>p.runDir?path.join(p.runDir,'backend',id):path.join(REPO,'artifacts','runs',st,'backend',id);

// --- parsing (minimal assumptions, Leandro-style) ---
const audioPkgs=txt=>Array.from((txt||'').matchAll(/\bpack:\s*([^\s]+)/g)).map(m=>m[1]);
const userIdFrom=txt=>{const m=(txt||'').match(/(\d+)/);return m?parseInt(m[1],10):-1;};
const sessionsBlock=(txt,uid)=>{txt=txt||'';const re=/Record for full_user=(\d+)/g;const ms=Array.from(txt.matchAll(re)).map(m=>({uid:parseInt(m[1],10),i:m.index??0}));
const at=ms.findIndex(m=>m.uid===uid);if(at<0)return '';const start=ms[at].i;const end=(at+1<ms.length)?ms[at+1].i:txt.length;
const block=txt.slice(start,end);const s=block.search(/Sessions Stack\s*-\s*have\s*\d+\s*sessions:/);return s<0?'':block.slice(s).trim();};
const splitEntries=blk=>{if(!blk)return [];const parts=blk.split(/\n\s{4}(?=\S)/).map(s=>s.trim()).filter(Boolean);return parts.length>1?parts.slice(1):[];};
const parseSessions=(txt,uid)=>splitEntries(sessionsBlock(txt,uid)).map(raw=>{const pkg=(raw.match(/package=([\w\.]+)/m)||[])[1]||null;
const a=(raw.match(/active=(true|false)/m)||[])[1];const active=a==='true'?true:(a==='false'?false:null);
const n=(raw.match(/\bstate=(\d+)/m)||[])[1];const stateNum=n?parseInt(n,10):null;
const brace=(raw.match(/\{state=([^\(\}]+)/m)||[])[1];const named=(raw.match(/\bstate=([A-Z_]+)/m)||[])[1];
const state=(brace||named||(stateNum!=null?String(stateNum):null));const desc=Array.from(raw.matchAll(/description=(.+)/g)).map(m=>m[1].trim());
const playing=(stateNum===3)||/STATE_PLAYING|\bPLAYING\b/i.test(raw)||/PLAYING/i.test(String(state||''));return{package:pkg,active,state,stateNum,playing,description:desc,raw};});
const pickSession=(sessions,pkgs)=>{pkgs=(pkgs||[]).filter(Boolean);for(const p of pkgs){const hit=sessions.find(s=>s.package===p);if(hit)return hit;}return sessions.find(s=>s&&s.active===true)||null;};

// --- core actions ---
const inject=(dev,code)=>run(adbArgs(dev,['shell','cmd','car_service','inject-custom-input','-r','0',String(code)]));

async function radioCheck(p){
  const dev=p.deviceId||'';const st=p.stamp||stamp();const id=p.testId||'unknown_test';
  const exp=p.packageName||DEFAULT_RADIO_PKG;
  const pkgs=(Array.isArray(p.expectedPackages)&&p.expectedPackages.length)?p.expectedPackages:[exp,...DEFAULT_SESSION_PKGS.filter(x=>x!==exp)];
  const dir=outDir(p,st,id);
  const a=await run(adbArgs(dev,['shell','dumpsys','audio']));
  const u=await run(adbArgs(dev,['shell','am','get-current-user']));
  const m=await run(adbArgs(dev,['shell','dumpsys','media_session']));
  write(dir,'dumpsys_audio.txt',a.stdout+(a.stderr?`\n\n[stderr]\n${a.stderr}`:''));write(dir,'current_user.txt',u.stdout+(u.stderr?`\n\n[stderr]\n${u.stderr}`:''));write(dir,'dumpsys_media_session.txt',m.stdout+(m.stderr?`\n\n[stderr]\n${m.stderr}`:''));
  const ap=audioPkgs(a.stdout);const audioFocus=ap.includes(exp);
  const uid=userIdFrom(u.stdout);const sessions=parseSessions(m.stdout,uid);const s=pickSession(sessions,pkgs);
  const mediaActive=!!(s&&s.active===true);const mediaPlaying=!!(s&&s.playing===true);
  const ok=!!(audioFocus&&mediaActive&&mediaPlaying);
  const verdict={ok,deviceId:dev,stamp:st,expectedPackage:exp,expectedPackages:pkgs,audio:{audioFocus,audioPackages:ap},userId:uid,
    media:s?{package:s.package,active:s.active,state:s.state,stateNum:s.stateNum,playing:mediaPlaying,description:s.description}:{package:null,active:null,state:null,stateNum:null,playing:false,description:[]},outDir:dir};
  write(dir,'backend_verdict.json',JSON.stringify(verdict,null,2));return verdict;
}

async function injectAction(p,kind){
  const dev=p.deviceId||'';const st=p.stamp||stamp();const id=p.testId||'inject';const dir=outDir(p,st,id);const steps=[];
  const push=async(name,promise)=>{const r=await promise;steps.push(step(name,r));return r;};

  if(kind==='ehh'){
    const setOne=async(which,disabled)=>{const prop=which==='phud'?'persist.vendor.com.bmwgroup.disable_phud_ehh':'persist.vendor.com.bmwgroup.disable_cid_ehh';
      const val=String(disabled).toLowerCase()==='true'?'true':'false';await push(`setprop ${prop} ${val}`,run(adbArgs(dev,['shell','setprop',prop,val])));};
    if(p.cidDisabled!==undefined)await setOne('cid',p.cidDisabled);
    if(p.phudDisabled!==undefined)await setOne('phud',p.phudDisabled);
    if(p.cidDisabled===undefined&&p.phudDisabled===undefined){await setOne((p.which||'cid')==='phud'?'phud':'cid',p.disabled??true);}
  }

  if(kind==='bim'){
    const raw=String((p.target!=null?p.target:p.action)||'mute').toLowerCase().trim();
    const action=(raw==='next')?'media-next':((raw==='prev'||raw==='previous')?'media-previous':raw);
    const doMuteFirst=String(p.muteFirst??'true').toLowerCase()!=='false';
    if(action==='mute'){
      await push('KEYCODE_MUTE',run(adbArgs(dev,['shell','input','keyevent','KEYCODE_MUTE'])));
    }else if(action==='media-next'||action==='media-previous'){
      if(doMuteFirst) await push('KEYCODE_MUTE',run(adbArgs(dev,['shell','input','keyevent','KEYCODE_MUTE'])));
      await push('swag media (1014)',inject(dev,1014));await push('swag media release (1015)',inject(dev,1015));
      const ev=action==='media-previous'?'KEYCODE_MEDIA_PREVIOUS':'KEYCODE_MEDIA_NEXT';await push(ev,run(adbArgs(dev,['shell','input','keyevent',ev])));
    }else{
      return{ok:false,kind,deviceId:dev,stamp:st,outDir:dir,error:'unknown_target',target:raw,allowedTargets:['mute','next','prev','previous','media-next','media-previous']};
    }
  }

  if(kind==='swag'){
    const raw=String((p.target!=null?p.target:p.action)||'').toLowerCase().trim();
    const action=(raw==='next')?'media-next':((raw==='prev'||raw==='previous')?'media-previous':raw);
    if(action==='media-next'||action==='media-previous'){
      await push('swag media (1014)',inject(dev,1014));await push('swag media release (1015)',inject(dev,1015));
      const ev=action==='media-previous'?'KEYCODE_MEDIA_PREVIOUS':'KEYCODE_MEDIA_NEXT';await push(ev,run(adbArgs(dev,['shell','input','keyevent',ev])));
    }else{
      const code=(p.keyCode!=null)?parseInt(p.keyCode,10):(SWAG[action]??null);
      if(code==null||Number.isNaN(code))return{ok:false,kind,deviceId:dev,stamp:st,outDir:dir,error:'unknown_target',target:raw,allowedTargets:Object.keys(SWAG).concat(['next','prev','previous','media-next','media-previous'])};
      await push(`inject ${code}`,inject(dev,code));await push(`inject ${code+1}`,inject(dev,code+1));
    }
  }

  const ok=steps.every(s=>(s.code??0)===0);const actionStamp=stamp();const file=`action_${kind}_${actionStamp}.json`;const res={ok,kind,deviceId:dev,stamp:st,actionStamp,testId:id,outDir:dir,artifactFile:file,steps,request:p};
  write(dir,file,JSON.stringify(res,null,2));return res;
}

// --- http server ---
http.createServer(async(req,res)=>{
  if(req.method==='OPTIONS')return jres(res,204,{ok:true});
  try{
    if(req.method==='GET'&&req.url==='/health')return jres(res,200,{ok:true,host:HOST,port:PORT});
    if(req.method==='POST'&&req.url==='/radio/check')return jres(res,200,await radioCheck(await readJson(req)));
    if(req.method==='POST'&&req.url==='/inject/swag')return jres(res,200,await injectAction(await readJson(req),'swag'));
    if(req.method==='POST'&&req.url==='/inject/bim')return jres(res,200,await injectAction(await readJson(req),'bim'));
    if(req.method==='POST'&&req.url==='/ehh/set')return jres(res,200,await injectAction(await readJson(req),'ehh'));
    return jres(res,404,{ok:false,error:'not_found'});
  }catch(e){return jres(res,500,{ok:false,error:String(e&&e.message?e.message:e)});}
}).listen(PORT,HOST,()=>console.log(`[control_server] http://${HOST}:${PORT}`));
