#!/usr/bin/env node
const http=require('http');const{spawn}=require('child_process');const fs=require('fs');const path=require('path');
const REPO=path.resolve(__dirname,'..','..');const ADB=process.env.ADB_BAT||path.join(REPO,'scripts','adb.bat');
const HOST=process.env.MAESTRO_CONTROL_HOST||'127.0.0.1';const PORT=parseInt(process.env.MAESTRO_CONTROL_PORT||'4567',10);
const ARTIFACTS_DIR=path.join(REPO,'artifacts');const AUDIT_FILE=path.join(ARTIFACTS_DIR,'control_server_audit.jsonl');

const DEFAULT_RADIO_PKG='com.bmwgroup.apinext.tunermediaservice';
const DEFAULT_SESSION_PKGS=[DEFAULT_RADIO_PKG,'com.bmwgroup.apinext.mediaapp','com.bmwgroup.idnext.vehiclemediacontrol.service','com.bmwgroup.apinext.onboardmediacontroller'];
const SWAG={up:1024,down:1028,left:1016,right:1020,center:1034,menu:1066,media:1014,phone:1054,ptt:1012};

const stamp=()=>{const d=new Date(),p=n=>String(n).padStart(2,'0');return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;}
const mkdir=d=>{try{fs.mkdirSync(d,{recursive:true});}catch(_){}}
const write=(d,f,c)=>{try{mkdir(d);fs.writeFileSync(path.join(d,f),c,'utf8');}catch(_){}}
const jres=(res,code,obj)=>{res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET,POST,OPTIONS','Access-Control-Allow-Headers':'Content-Type'});res.end(JSON.stringify(obj,null,2));}
const audit=[]; let latestRadioVerdict=null;
const appendAuditFile=(lineObj)=>{try{mkdir(ARTIFACTS_DIR);fs.appendFileSync(AUDIT_FILE,JSON.stringify(lineObj)+'\n','utf8');}catch(_){}};
const auditPush=(evt)=>{const row=Object.assign({ts:new Date().toISOString()},evt||{});audit.push(row);if(audit.length>300)audit.shift();appendAuditFile(row);};
const latestSummary=()=>{if(!latestRadioVerdict)return null;return{ok:latestRadioVerdict.ok===true,deviceId:latestRadioVerdict.deviceId||'',deviceDetails:latestRadioVerdict.deviceDetected?latestRadioVerdict.deviceDetected.details||'':'',stamp:latestRadioVerdict.stamp||'',expectedPackage:latestRadioVerdict.expectedPackage||'',media:latestRadioVerdict.media?{package:latestRadioVerdict.media.package,playing:latestRadioVerdict.media.playing,state:latestRadioVerdict.media.state,metadataTitle:latestRadioVerdict.media.metadataTitle,metadataArtist:latestRadioVerdict.media.metadataArtist,queueTitle:latestRadioVerdict.media.queueTitle}:null,ui:latestRadioVerdict.ui?{station:latestRadioVerdict.ui.station,band:latestRadioVerdict.ui.band}:null,audio:latestRadioVerdict.audio?{audioFocus:latestRadioVerdict.audio.audioFocus}:null,outDir:latestRadioVerdict.outDir||''};};
const readAuditTail=(limit)=>{try{if(!fs.existsSync(AUDIT_FILE))return [];const txt=fs.readFileSync(AUDIT_FILE,'utf8');const lines=txt.split(/\r?\n/).filter(Boolean);return lines.slice(-limit).map(l=>{try{return JSON.parse(l);}catch(_){return{raw:l,parseError:true};}});}catch(_){return[];}};
const readJson=req=>new Promise((ok,fail)=>{let b='';req.on('data',c=>b+=c.toString('utf8'));req.on('end',()=>{if(!b.trim())return ok({});try{ok(JSON.parse(b));}catch(e){fail(e);}});});
const adbArgs=(dev,rest)=>dev?['-s',dev,...rest]:rest;
const run=(args,timeout=25000)=>new Promise(ok=>{const isWin=process.platform==='win32';const cmd=isWin?'cmd.exe':ADB;const cmdArgs=isWin?['/c',ADB,...args]:args;const ch=spawn(cmd,cmdArgs,{cwd:REPO,windowsHide:true});
let out='',err='';const t=setTimeout(()=>{try{ch.kill('SIGKILL');}catch(_){}},timeout);
ch.stdout.on('data',d=>out+=d.toString());ch.stderr.on('data',d=>err+=d.toString());
ch.on('close',code=>{clearTimeout(t);ok({code:code??0,stdout:out,stderr:err});});});
const step=(name,r)=>({name,code:r.code??0,stdout:r.stdout||'',stderr:r.stderr||''});
const outDir=(p,st,id)=>p.runDir?path.join(p.runDir,'backend',id):path.join(REPO,'artifacts','runs',st,'backend',id);
const parseFirstDevice=(txt)=>{const lines=(txt||'').split(/\r?\n/).map(s=>s.trim()).filter(Boolean);for(const ln of lines){if(/^List of devices attached/i.test(ln))continue;const m=ln.match(/^(\S+)\s+device\s*(.*)$/);if(m){return{serial:m[1],details:m[2]||''};}}return null;};

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
const q=(raw.match(/queueTitle=([^,\n]+),\s*size=(\d+)/m)||[]);const queueTitle=q[1]?q[1].trim():null;const queueSize=q[2]?parseInt(q[2],10):null;
const md=(raw.match(/metadata:\s*size=\d+,\s*description=(.+)/m)||[])[1]||null;const mdParts=md?md.split(',').map(s=>s.trim()):[];
const metadataTitle=(mdParts[0]&&mdParts[0]!=='null')?mdParts[0]:null;const metadataArtist=(mdParts[1]&&mdParts[1]!=='null')?mdParts[1]:null;
const playing=(stateNum===3)||/STATE_PLAYING|\bPLAYING\b/i.test(raw)||/PLAYING/i.test(String(state||''));return{package:pkg,active,state,stateNum,playing,description:desc,queueTitle,queueSize,metadataDescription:md,metadataTitle,metadataArtist,raw};});
const pickSession=(sessions,pkgs)=>{pkgs=(pkgs||[]).filter(Boolean);for(const p of pkgs){const hit=sessions.find(s=>s.package===p);if(hit)return hit;}return sessions.find(s=>s&&s.active===true)||null;};
const extractXml=(txt)=>{const s=(txt||'').indexOf('<?xml');return s>=0?(txt||'').slice(s):'';};
const parseUiRadio=(xml)=>{xml=xml||'';let station=(xml.match(/resource-id="TEST_TAG_HEADER"[\s\S]{0,1500}?text="([^"]+)"/m)||[])[1]||null;const icon=(xml.match(/icon_([a-z0-9_]+)_tuner/i)||[])[1]||null;let band=null;if(icon){if(icon.includes('fm'))band='FM';else if(icon.includes('am'))band='AM';else if(icon.includes('dab'))band='DAB';else band=icon.toUpperCase();}
if(!station){const nodes=Array.from(xml.matchAll(/text="([^"]+)"[^>]*resource-id="TextAtom:dynamic_string\/[^"]+"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/g)).map(m=>({text:m[1],x1:parseInt(m[2],10),y1:parseInt(m[3],10),x2:parseInt(m[4],10),y2:parseInt(m[5],10)}));const cand=nodes.filter(n=>n.text&&n.text!=='Radio'&&n.y1>=280&&n.y1<=540&&((n.y2-n.y1)>=60||(n.x2-n.x1)>=200)).sort((a,b)=>a.y1-b.y1)[0];if(cand)station=cand.text;}
return{station,band,icon};};

// --- core actions ---
const inject=(dev,code)=>run(adbArgs(dev,['shell','cmd','car_service','inject-custom-input','-r','0',String(code)]));

async function radioCheck(p){
  let dev=p.deviceId||'';const st=p.stamp||stamp();const id=p.testId||'unknown_test';
  const exp=p.packageName||DEFAULT_RADIO_PKG;
  const pkgs=(Array.isArray(p.expectedPackages)&&p.expectedPackages.length)?p.expectedPackages:[exp,...DEFAULT_SESSION_PKGS.filter(x=>x!==exp)];
  const dir=outDir(p,st,id);
  let detectedDevice=null;
  if(!dev){const d=await run(['devices','-l'],10000);detectedDevice=parseFirstDevice(d.stdout);if(detectedDevice&&detectedDevice.serial)dev=detectedDevice.serial;}
  const a=await run(adbArgs(dev,['shell','dumpsys','audio']));
  const u=await run(adbArgs(dev,['shell','am','get-current-user']));
  const m=await run(adbArgs(dev,['shell','dumpsys','media_session']));
  const x1=await run(adbArgs(dev,['exec-out','uiautomator','dump','/dev/tty']),12000);
  let xml=extractXml((x1.stdout||'')+(x1.stderr?`\n${x1.stderr}`:''));
  let uiDumpMethod='exec-out:/dev/tty';
  if(!xml){
    const x2=await run(adbArgs(dev,['shell','uiautomator','dump','/sdcard/window_dump.xml']),12000);
    const x3=await run(adbArgs(dev,['shell','cat','/sdcard/window_dump.xml']),12000);
    xml=extractXml((x3.stdout||'')+(x2.stdout?`\n${x2.stdout}`:'')+(x2.stderr?`\n${x2.stderr}`:''));
    uiDumpMethod='shell:/sdcard/window_dump.xml';
  }
  const ui=parseUiRadio(xml);
  write(dir,'dumpsys_audio.txt',a.stdout+(a.stderr?`\n\n[stderr]\n${a.stderr}`:''));write(dir,'current_user.txt',u.stdout+(u.stderr?`\n\n[stderr]\n${u.stderr}`:''));write(dir,'dumpsys_media_session.txt',m.stdout+(m.stderr?`\n\n[stderr]\n${m.stderr}`:''));write(dir,'ui_dump_debug.txt',`method=${uiDumpMethod}\nxml_found=${xml? 'true':'false'}\n`);if(xml)write(dir,'ui_dump.xml',xml);
  const ap=audioPkgs(a.stdout);const audioFocus=ap.includes(exp);
  const uid=userIdFrom(u.stdout);const sessions=parseSessions(m.stdout,uid);const s=pickSession(sessions,pkgs);
  const mediaActive=!!(s&&s.active===true);const mediaPlaying=!!(s&&s.playing===true);
  const ok=!!(audioFocus&&mediaActive&&mediaPlaying);
  const verdict={ok,deviceId:dev,deviceDetected:detectedDevice,stamp:st,expectedPackage:exp,expectedPackages:pkgs,audio:{audioFocus,audioPackages:ap},ui,uiDumpMethod,userId:uid,
    media:s?{
      package:s.package,active:s.active,state:s.state,stateNum:s.stateNum,playing:mediaPlaying,description:s.description,
      queueTitle:s.queueTitle,queueSize:s.queueSize,metadataDescription:s.metadataDescription,metadataTitle:s.metadataTitle,metadataArtist:s.metadataArtist
    }:{package:null,active:null,state:null,stateNum:null,playing:false,description:[],queueTitle:null,queueSize:null,metadataDescription:null,metadataTitle:null,metadataArtist:null},outDir:dir};
  write(dir,'backend_verdict.json',JSON.stringify(verdict,null,2));latestRadioVerdict=verdict;auditPush({type:'radio_check',ok:verdict.ok===true,deviceId:dev||'',deviceDetails:detectedDevice?detectedDevice.details||'':'',testId:id||'',expectedPackage:exp||'',media:verdict.media?{package:verdict.media.package,playing:verdict.media.playing,state:verdict.media.state,metadataTitle:verdict.media.metadataTitle,metadataArtist:verdict.media.metadataArtist,queueTitle:verdict.media.queueTitle}:null,ui:verdict.ui?{station:verdict.ui.station,band:verdict.ui.band}:null,audio:verdict.audio?{audioFocus:verdict.audio.audioFocus}:null,outDir:dir});return verdict;
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
  write(dir,file,JSON.stringify(res,null,2));auditPush({type:'inject_action',ok:ok===true,kind,deviceId:dev||'',testId:id||'',outDir:dir,artifactFile:file});return res;
}

// --- http server ---
http.createServer(async(req,res)=>{
  if(req.method==='OPTIONS')return jres(res,204,{ok:true});
  try{
    const u=new URL(req.url||'/',`http://${HOST}:${PORT}`);const p=u.pathname;
    if(req.method==='GET'&&p==='/dashboard'){
      const html=`<!doctype html><html><head><meta charset="utf-8"/><title>Maestro Control Dashboard</title><style>body{font-family:Segoe UI,Arial,sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:16px}h1{margin:0 0 12px;font-size:20px}.grid{display:grid;grid-template-columns:repeat(2,minmax(320px,1fr));gap:12px}.card{background:#111827;border:1px solid #334155;border-radius:10px;padding:12px}.ok{color:#22c55e}.bad{color:#ef4444}.muted{color:#94a3b8}pre{white-space:pre-wrap;word-break:break-word;background:#020617;padding:10px;border-radius:8px;max-height:360px;overflow:auto}a{color:#38bdf8}</style></head><body><h1>Maestro Control Dashboard</h1><div class="muted">Auto-refresh: 1s · <a href="/">JSON root</a> · <a href="/audit/file/raw?limit=2000" download="control_server_audit.jsonl">Download persisted audit (JSONL)</a></div><div class="grid"><div class="card"><h3>Latest Verdict</h3><div id="verdict" class="muted">No data yet</div></div><div class="card"><h3>Track / Station</h3><div id="track" class="muted">No data yet</div></div><div class="card"><h3>Recent Audit</h3><pre id="audit">[]</pre></div><div class="card"><h3>Raw Last Verdict</h3><pre id="raw">null</pre></div></div><script>async function load(){try{const a=await fetch('/radio/last').then(r=>r.json());const b=await fetch('/audit?limit=30').then(r=>r.json());const l=a&&a.latest?a.latest:null;document.getElementById('verdict').innerHTML=l?('ok: <b class="'+(l.ok?'ok':'bad')+'">'+l.ok+'</b><br/>audioFocus: <b class="'+((l.audio&&l.audio.audioFocus)?'ok':'bad')+'">'+(l.audio&&l.audio.audioFocus)+'</b><br/>playing: <b class="'+((l.media&&l.media.playing)?'ok':'bad')+'">'+(l.media&&l.media.playing)+'</b><br/>package: '+((l.media&&l.media.package)||'-')+'<br/>state: '+((l.media&&l.media.state)||'-')+'<br/>device: '+(l.deviceId||'-')+'<br/>deviceDetails: '+(l.deviceDetails||'-')+'<br/>stamp: '+(l.stamp||'-')+'<br/>outDir: '+(l.outDir||'-')):'No data yet';const raw=a&&a.raw?a.raw:null;const m=raw&&raw.media?raw.media:{};document.getElementById('track').innerHTML='title: '+(m.metadataTitle||'-')+'<br/>artist: '+(m.metadataArtist||'-')+'<br/>station(UI): '+((raw&&raw.ui&&raw.ui.station)||'-')+'<br/>band(UI): '+((raw&&raw.ui&&raw.ui.band)||'-')+'<br/>station/list: '+(m.queueTitle||'-')+'<br/>description: '+((m.description&&m.description.join(' | '))||'-');const ev=((b&&b.events)||[]).slice(-12).reverse();document.getElementById('audit').textContent=JSON.stringify(ev,null,2);document.getElementById('raw').textContent=JSON.stringify(raw,null,2);}catch(e){document.getElementById('verdict').textContent='Dashboard fetch error: '+String(e);}}async function probe(){try{await fetch('/radio/probe');}catch(_){}}load();setInterval(load,1000);setInterval(probe,5000);</script></body></html>`;
      res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});return res.end(html);
    }
    if(req.method==='GET'&&p==='/')return jres(res,200,{ok:true,service:'maestro_control_server',host:HOST,port:PORT,auditFile:AUDIT_FILE,endpoints:['GET /','GET /dashboard','GET /health','GET /audit?limit=20','GET /audit/file?limit=50','GET /audit/file/raw?limit=500','GET /radio/last','GET /radio/probe','POST /radio/check','POST /inject/swag','POST /inject/bim','POST /ehh/set'],latest:latestSummary()});
    if(req.method==='GET'&&p==='/health')return jres(res,200,{ok:true,host:HOST,port:PORT,latest:latestSummary()});
    if(req.method==='GET'&&p==='/radio/last')return jres(res,200,{ok:true,latest:latestSummary(),raw:latestRadioVerdict});
    if(req.method==='GET'&&p==='/radio/probe')return jres(res,200,await radioCheck({testId:'dashboard_probe'}));
    if(req.method==='GET'&&p==='/audit'){const lim=Math.max(1,Math.min(200,parseInt(u.searchParams.get('limit')||'20',10)||20));return jres(res,200,{ok:true,count:Math.min(lim,audit.length),events:audit.slice(-lim)});}
    if(req.method==='GET'&&p==='/audit/file'){const lim=Math.max(1,Math.min(500,parseInt(u.searchParams.get('limit')||'50',10)||50));const ev=readAuditTail(lim);return jres(res,200,{ok:true,file:AUDIT_FILE,count:ev.length,events:ev});}
    if(req.method==='GET'&&p==='/audit/file/raw'){try{const lim=Math.max(1,Math.min(5000,parseInt(u.searchParams.get('limit')||'500',10)||500));const ev=readAuditTail(lim);const body=ev.map(e=>JSON.stringify(e)).join('\n')+(ev.length?'\n':'');res.writeHead(200,{'Content-Type':'application/x-ndjson; charset=utf-8','Content-Disposition':'attachment; filename="control_server_audit.jsonl"'});return res.end(body);}catch(_){return jres(res,500,{ok:false,error:'audit_read_failed'});}}
    if(req.method==='POST'&&p==='/radio/check')return jres(res,200,await radioCheck(await readJson(req)));
    if(req.method==='POST'&&p==='/inject/swag')return jres(res,200,await injectAction(await readJson(req),'swag'));
    if(req.method==='POST'&&p==='/inject/bim')return jres(res,200,await injectAction(await readJson(req),'bim'));
    if(req.method==='POST'&&p==='/ehh/set')return jres(res,200,await injectAction(await readJson(req),'ehh'));
    return jres(res,404,{ok:false,error:'not_found',path:p});
  }catch(e){return jres(res,500,{ok:false,error:String(e&&e.message?e.message:e)});}
}).listen(PORT,HOST,()=>{auditPush({type:'server_start',ok:true,host:HOST,port:PORT,pid:process.pid});console.log(`[control_server] http://${HOST}:${PORT}`);});
