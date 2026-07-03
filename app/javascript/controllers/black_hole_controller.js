import { Controller } from "@hotwired/stimulus"

// Black-hole canvas engine — ported from the Depth Charge design handoff
// (docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html).
// Homepage only. Depth camera follows scroll; hovering the hole charges it
// (idle → charging → hold → decay → explode); explosions morph the hero
// text between "web developer" and "Louis Bourne".
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    intensity: { type: Number, default: 70 },
    animate: { type: Boolean, default: true },
    starfield: { type: Boolean, default: true }
  }

  // Accretion-disk palette, inner → outer (from the mock).
  PAL = [[240, 248, 255], [85, 205, 245], [42, 120, 250], [85, 95, 232], [150, 82, 220], [210, 84, 162]]

  connect() {
    // A canvas failure must never break the page — content sits above the
    // canvas and works without it.
    try {
      this.ctrl = this.initBH(this.canvasTarget)
    } catch (e) {
      console.error("black-hole engine failed to start", e)
    }
    // Turbo snapshots the DOM before caching a page. Reset the morphing
    // hero text and clear the canvas first, so back-navigation never
    // flashes a half-morphed headline or a frozen frame.
    this.beforeCache = () => {
      if (this.ctrl && this.ctrl.resetForCache) this.ctrl.resetForCache()
    }
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    // Turbo-safe teardown: stop the rAF loop and remove window listeners.
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    if (this.ctrl && this.ctrl.stop) this.ctrl.stop()
    this.ctrl = null
  }

  initBH(cv) {
    const ctx=cv.getContext('2d');
    const inten = this.intensityValue / 70;
    const animate = this.animateValue;
    const reduceMedia=window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const reduce=reduceMedia||!animate;
    const starsOn = this.starfieldValue;
    const dpr=Math.min(window.devicePixelRatio||1,2);
    const PAL = this.PAL, tilt=0.34, core=0.13;
    let w=0,h=0,R=1,rMax=1;
    let parts=[],orbits=[],stars=[],energyParts=[],bpool=[],bcount=0;
    // charge/energy system
    let phase='idle',chargeE=0,boom=0,excite=0,vFloor=0,power=0,bmult=2.5,energy=0,iterationsDone=0,textFrozen=false,holdT=0,decRate=0;
    // cursor
    let mx=-9999,my=-9999,hover=false,glowX=0,glowY=0,glowA=0;
    // depth camera + scroll
    let sc=1,curSc=1,cyOff=0,camCx=0,camCy=0,Re=1,rMe=1,vel=0,lastTop=0,heroT=0,cxN=0.5,cyN=0.5,briMul=1;

    function col(t){ t=t<0?0:t>1?1:t; const f=t*(PAL.length-1),i=Math.floor(f),j=Math.min(i+1,PAL.length-1),k=f-i,A=PAL[i],B=PAL[j]; return [A[0]+(B[0]-A[0])*k,A[1]+(B[1]-A[1])*k,A[2]+(B[2]-A[2])*k]; }

    function build(){
      R=Math.min(w,h)*core; rMax=R*4.5;
      const count=Math.max(640,Math.min(3000,Math.round(w*h/1300)));
      parts=[];
      for(let i=0;i<count;i++){ const rr=R*1.08+Math.pow(Math.random(),.55)*(rMax-R*1.08); parts.push({a:rr,r:rr,ang:Math.random()*6.2832,spd:.2/Math.sqrt(rr/R)*(.85+Math.random()*.3),size:.5+Math.random()*1.7,br:.2+Math.random()*.8,t:(rr-R)/(rMax-R),ox:0,oy:0}); }
      orbits=[];
      [90,45,135,25,155].forEach(deg=>{ const o={phi:deg*Math.PI/180,thin:.16+Math.random()*.06,list:[]}; const oc=Math.round(count*.32); for(let i=0;i<oc;i++){ const rr=R*1.12+Math.pow(Math.random(),.6)*(rMax*.7-R*1.12); o.list.push({a:rr,r:rr,ang:Math.random()*6.2832,spd:.3/Math.sqrt(rr/R)*(.85+Math.random()*.3),size:.5+Math.random()*1.4,br:.25+Math.random()*.7,ox:0,oy:0}); } orbits.push(o); });
      energyParts=[]; const ec=Math.round(count*1.1); for(let i=0;i<ec;i++){ const rr=R*1.08+Math.pow(Math.random(),.55)*(rMax-R*1.08); energyParts.push({a:rr,r:rr,ang:Math.random()*6.2832,spd:.2/Math.sqrt(rr/R)*(.85+Math.random()*.3),size:.5+Math.random()*1.6,br:.2+Math.random()*.8,t:(rr-R)/(rMax-R),ox:0,oy:0}); }
      stars=[]; if(starsOn){ const s=Math.round(w*h/9500); for(let i=0;i<s;i++) stars.push({x:Math.random()*w,y:Math.random()*h,r:Math.random()*1.1+.2,b:.2+Math.random()*.6,tw:Math.random()*6.28}); }
      bpool=[]; bcount=0;
    }
    function resize(){ w=Math.max(1,document.documentElement.clientWidth||window.innerWidth); h=Math.max(1,window.innerHeight); cv.style.width=w+'px'; cv.style.height=h+'px'; cv.width=Math.round(w*dpr); cv.height=Math.round(h*dpr); ctx.setTransform(dpr,0,0,dpr,0,0); build(); }
    function readScroll(){ const secs=document.querySelectorAll('[data-sec]'); const n=secs.length; const de=document.documentElement; const max=Math.max(1,(de.scrollHeight||document.body.scrollHeight)-window.innerHeight); const top=window.scrollY||window.pageYOffset||0; const prog=Math.max(0,Math.min(1,top/max)); const vh=window.innerHeight; let ci=0,best=1e9; for(let i=0;i<n;i++){ const r=secs[i].getBoundingClientRect(); const c=r.top+r.height/2; const d=Math.abs(c-vh/2); if(d<best){best=d;ci=i;} } return {n,prog,ci,secs}; }

    // ---- hero text morph (from charge level) ----
    const SUB_START='Louis Bourne, full-stack developer building production Ruby-on-Rails products from Thailand.';
    const SUB_END='Known for being incredibly handsome and talented.';
    function blendStr(s,t,p){ if(p>=1) return t; const n=Math.floor(t.length*p); let out=''; const m=Math.max(s.length,t.length); for(let i=0;i<m;i++){ if(i<n) out+=t[i]; else if(i<s.length) out+=s[i]; } return out; }
    function morphSub(el,startStr,endStr,frac){ if(!el) return; const len=Math.max(startStr.length,endStr.length); const key=startStr+'|'+endStr; if(el._subKey!==key){ const idx=[]; for(let i=0;i<len;i++) idx.push(i); for(let i=len-1;i>0;i--){ const j=(Math.random()*(i+1))|0; const t=idx[i]; idx[i]=idx[j]; idx[j]=t; } el._suborder=idx; el._subKey=key; } const order=el._suborder; const lockN=Math.floor(frac*len); const locked=new Set(order.slice(0,lockN)); let out=''; for(let i=0;i<len;i++){ if(locked.has(i)) out+=(endStr[i]!=null?endStr[i]:' '); else out+=(startStr[i]!=null?startStr[i]:' '); } if(el._cur!==out){ el.textContent=out; el._cur=out; } }
    function renderText(e){ e=Math.max(0,Math.min(8,Math.ceil(e-1e-6))); const e1=document.querySelector('[data-morph="1"]'),e2=document.querySelector('[data-morph="2"]'),es=document.querySelector('[data-morph="sub"]'); let s1,s2; if(e<=6){ const p=e/6; s1=blendStr('web','Louis',p); s2=blendStr('developer','Bourne',p); if(es) morphSub(es,SUB_START,SUB_END,p); } else { const rp=Math.min(1,(e-6)/2); s1=blendStr('Louis','web',rp); s2=blendStr('Bourne','developer',rp); if(es) morphSub(es,SUB_END,SUB_START,rp); } if(e1&&e1._cur!==s1){ e1.textContent=s1; e1._cur=s1; } if(e2&&e2._cur!==s2){ e2.textContent=s2; e2._cur=s2; } }

    function spawnBurst(){ const cols=[[90,180,255],[120,200,255],[80,140,255],[150,205,255],[255,255,255]]; const n=Math.round(parts.length*bmult); const lvf=1+Math.min(power,13)*.16; for(let i=0;i<n;i++){ let b=bpool[i]; if(!b){b={};bpool[i]=b;} const ang=Math.random()*6.2832; const sp=(.6+Math.random()*1.7)*rMax*sc*lvf; b.x=camCx+Math.cos(ang)*Re*.9; b.y=camCy+Math.sin(ang)*Re*.4; b.vx=Math.cos(ang)*sp; b.vy=Math.sin(ang)*sp*.62; b.life=.8+Math.random()*1.0; b.maxlife=b.life; b.size=.8+Math.random()*2.3; b.col=cols[(Math.random()*cols.length)|0]; } bcount=n; }

    function stepCharge(dt){
      const cx=camCx, cy=camCy;
      const over = hover && Math.hypot(mx-cx,my-cy) < Re*1.7;
      if(phase==='idle'){ if(over) phase='charging'; }
      else if(phase==='charging'){
        if(over){ chargeE += dt/2.5;
          if(chargeE>=1){ chargeE=0; phase='explode'; boom=1; if(excite>=8){ iterationsDone++; vFloor=Math.min(3, iterationsDone*1.5); excite=0; } excite=Math.min(8, Math.floor(excite+1e-9)+1); textFrozen=(excite>=8); const ph=excite; power=(ph<=6)?ph:(ph===7?9:13); bmult=2.5+power*0.95; renderText(textFrozen?0:excite); spawnBurst(); }
        } else { phase='hold'; holdT=2; }
      } else if(phase==='hold'){
        if(over){ phase='charging'; } else { holdT-=dt; if(holdT<=0){ phase='decay'; decRate=(chargeE>0?chargeE/3:1); } }
      } else if(phase==='decay'){
        if(over){ phase='charging'; } else { chargeE -= decRate*dt; if(chargeE<=0){ chargeE=0; phase='idle'; } }
      } else if(phase==='explode'){ boom -= dt/1.15; if(over && boom<0.5){ chargeE=Math.min(0.6, chargeE+dt/2.5); } if(boom<=0){ boom=0; phase = over ? 'charging' : 'idle'; } }
      if(!(phase==='charging'||phase==='explode')) excite=Math.max(0,excite-dt/10);
      const vLev=Math.max(excite,vFloor);
      energy=Math.max(Math.min(1,vLev/3), chargeE, boom);
      renderText(textFrozen?0:excite);
      const ch=chargeE, exploding=(phase==='explode');
      const lf=1+Math.min(power,13)*0.26;
      const ss=1+vel*2;
      for(const p of parts){ p.ang += p.spd*dt*((1+ch*4.5+boom*3)*lf)*ss; const rt = exploding ? (p.a + boom*rMax*0.7*lf) : (R*1.1 + (p.a-R*1.1)*(1-ch*0.86)); p.r += (rt-p.r)*Math.min(1,dt*4.5); p.ox+=-p.ox*Math.min(1,dt*5); p.oy+=-p.oy*Math.min(1,dt*5); if(hover && !exploding){ const x=cx+Math.cos(p.ang)*p.r*sc, y=cy+Math.sin(p.ang)*p.r*sc*tilt; const ddx=x-mx,ddy=y-my,d2=ddx*ddx+ddy*ddy; if(d2<12100&&d2>1){ const d=Math.sqrt(d2); const f=(1-d/110)*30; p.ox+=ddx/d*f; p.oy+=ddy/d*f; } } }
      for(let oi=0;oi<orbits.length;oi++){ const o=orbits[oi]; const ca=Math.cos(o.phi),sa=Math.sin(o.phi); const spB=(1+ch*6+boom*3)*(1+Math.min(power,13)*0.3)*(1+oi*0.12)*(1+Math.max(excite,vFloor)*0.18)*ss; for(const p of o.list){ p.ang += p.spd*dt*spB; const rt = exploding ? (p.a+boom*rMax*0.62*lf) : (R*1.05 + (p.a-R*1.05)*(1-ch*0.82)); p.r += (rt-p.r)*Math.min(1,dt*4.5); p.ox+=-p.ox*Math.min(1,dt*5); p.oy+=-p.oy*Math.min(1,dt*5); if(hover && !exploding){ const ex=Math.cos(p.ang)*p.r*sc, ey=Math.sin(p.ang)*p.r*sc*o.thin; const x=cx+ex*ca-ey*sa+p.ox, y=cy+ex*sa+ey*ca+p.oy; const ddx=x-mx,ddy=y-my,d2=ddx*ddx+ddy*ddy; if(d2<12100&&d2>1){ const d=Math.sqrt(d2); const f=(1-d/110)*30; p.ox+=ddx/d*f; p.oy+=ddy/d*f; } } } }
      for(const p of energyParts){ p.ang += p.spd*dt*((1+ch*4.5+boom*3)*lf)*ss; const rt = exploding ? (p.a + boom*rMax*0.7*lf) : (R*1.1 + (p.a-R*1.1)*(1-ch*0.86)); p.r += (rt-p.r)*Math.min(1,dt*4.5); p.ox+=-p.ox*Math.min(1,dt*5); p.oy+=-p.oy*Math.min(1,dt*5); }
      if(bcount>0){ for(let i=0;i<bcount;i++){ const b=bpool[i]; if(!b||b.life<=0) continue; b.life-=dt; b.x+=b.vx*dt; b.y+=b.vy*dt; b.vx*=(1-Math.min(0.9,dt*0.7)); b.vy*=(1-Math.min(0.9,dt*0.7)); } }
    }

    function drawParts(far,list,aMul){
      list=list||parts; aMul=(aMul==null)?1:aMul;
      ctx.globalCompositeOperation='lighter';
      for(const p of list){ const sy=Math.sin(p.ang); if((sy<0)!==far) continue; const x=camCx+Math.cos(p.ang)*p.r*sc*1.5+p.ox; const y=camCy+sy*p.r*sc*tilt+p.oy; let c=col(p.t); let hl=0; if(hover){ const dx=x-mx,dy=y-my,d2=dx*dx+dy*dy; if(d2<16900){ hl=1-Math.sqrt(d2)/130; } } hl=Math.max(hl,chargeE*0.5,boom*0.85); if(hl>0){ c=[c[0]+(185-c[0])*hl,c[1]+(222-c[1])*hl,c[2]+(255-c[2])*hl]; } const edge=.5+.5*Math.abs(Math.cos(p.ang)); const a=Math.min(1,(p.br*edge*inten*briMul*(.55+.45*(1-p.t))+hl*0.4)*aMul); ctx.fillStyle='rgba('+(c[0]|0)+','+(c[1]|0)+','+(c[2]|0)+','+a+')'; ctx.beginPath(); ctx.arc(x,y,p.size,0,6.2832); ctx.fill(); }
    }
    function drawOrbits(far){
      const spike=Math.max(chargeE,boom);
      ctx.globalCompositeOperation='lighter';
      const gold=[255,198,92], cyan=[150,205,255];
      for(let oi=0;oi<orbits.length;oi++){ const o=orbits[oi]; const eff=Math.max(excite,vFloor)+spike; const rv=Math.min(1,Math.max(0,eff-oi*0.9)); if(rv<=0.02) continue; const cs=Math.max(0,Math.min(1,(rv-0.15)/0.5)); const c=[cyan[0]+(gold[0]-cyan[0])*cs,cyan[1]+(gold[1]-cyan[1])*cs,cyan[2]+(gold[2]-cyan[2])*cs]; const ca=Math.cos(o.phi),sa=Math.sin(o.phi); for(const p of o.list){ const depth=Math.sin(p.ang); if((depth<0)!==far) continue; const ex=Math.cos(p.ang)*p.r*sc, ey=Math.sin(p.ang)*p.r*sc*o.thin; const x=camCx+(ex*ca-ey*sa)*1.5+(p.ox||0), y=camCy+ex*sa+ey*ca+(p.oy||0); const a=Math.min(1,p.br*rv*inten*briMul*(.55+.45*Math.abs(Math.cos(p.ang)))); ctx.fillStyle='rgba('+(c[0]|0)+','+(c[1]|0)+','+(c[2]|0)+','+a+')'; ctx.beginPath(); ctx.arc(x,y,p.size*(1+boom*1.2),0,6.2832); ctx.fill(); } }
    }
    function drawBurst(){ if(bcount<=0) return; ctx.globalCompositeOperation='lighter'; for(let i=0;i<bcount;i++){ const b=bpool[i]; if(!b||b.life<=0) continue; const a=Math.min(1,b.life/b.maxlife)*inten; ctx.fillStyle='rgba('+b.col[0]+','+b.col[1]+','+b.col[2]+','+a+')'; ctx.beginPath(); ctx.arc(b.x,b.y,b.size,0,6.2832); ctx.fill(); } }

    function render(dt,time){
      // scroll-driven depth camera
      const S=readScroll(); const {n,prog,ci,secs}=S;
      const top=window.scrollY||window.pageYOffset||0; const dv=Math.abs(top-lastTop); lastTop=top; vel+=((Math.min(1,dv/55))-vel)*Math.min(1,dt*6);
      const depthv=Math.max(0,1-Math.abs(prog-.5)*2); const tscl=.5+depthv*1.75; const endPush=Math.max(0,(prog-0.9)/0.1);
      let tcyl=(prog-.5)*.1;
      if(endPush>0){ const _f=document.querySelector('#contact form'), _ft=document.querySelector('footer'); if(_f&&_ft){ const _fr=_f.getBoundingClientRect(), _fo=_ft.getBoundingClientRect(); const _off=((_fr.bottom+_fo.top)/2)/h-0.5; const e=endPush*endPush; tcyl=tcyl*(1-e)+_off*e; } }
      curSc+=(tscl-curSc)*Math.min(1,dt*3.5); cyOff+=(tcyl-cyOff)*Math.min(1,dt*3);
      sc=curSc; camCx=w*0.5; camCy=h*0.5+cyOff*h; Re=R*sc; rMe=rMax*sc; briMul=1.45;
      const ke=Math.min(1,dt*9); if(mx<-9000){ glowX=camCx; glowY=camCy; } else { glowX+=(mx-glowX)*ke; glowY+=(my-glowY)*ke; } glowA+=((hover?1:0)-glowA)*Math.min(1,dt*6);
      if(!reduce) stepCharge(dt);

      ctx.clearRect(0,0,w,h);
      const cc=col(0.35); const bg=ctx.createRadialGradient(camCx,camCy,Re*.5,camCx,camCy,rMe*1.4); bg.addColorStop(0,'rgba('+(cc[0]|0)+','+(cc[1]|0)+','+(cc[2]|0)+','+(0.1*inten*briMul)+')'); bg.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=bg; ctx.fillRect(0,0,w,h);
      ctx.globalCompositeOperation='lighter';
      for(const s of stars){ const tw=reduce?1:(.6+.4*Math.sin(time*1.5+s.tw)); ctx.fillStyle='rgba(200,214,235,'+(s.b*tw*.7)+')'; ctx.beginPath(); ctx.arc(s.x,s.y,s.r,0,6.2832); ctx.fill(); }
      drawParts(true); drawParts(true,energyParts,energy); drawOrbits(true);
      ctx.globalCompositeOperation='source-over';
      const bd=ctx.createRadialGradient(camCx,camCy,Re*.15,camCx,camCy,Re*1.14); bd.addColorStop(0,'#000'); bd.addColorStop(.72,'#000'); bd.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=bd; ctx.beginPath(); ctx.arc(camCx,camCy,Re*1.16,0,6.2832); ctx.fill();
      // accretion ring, pulses with charge/energy
      ctx.globalCompositeOperation='lighter'; ctx.save(); const pr=col(0.05), rc=[255,248,236]; let rblur=18,rsa=0.55; const vLev=Math.max(excite,vFloor); const eng=Math.min(1.6, vLev/3 + Math.max(chargeE,boom)); if(eng>0.02){ const pulse=0.5+0.5*Math.sin(time*1.3); rblur=18+(28+vLev*11)*pulse*eng; rsa=Math.min(1,0.5+(0.4+vLev*0.06)*pulse*eng); } ctx.shadowColor='rgba('+(pr[0]|0)+','+(pr[1]|0)+','+(pr[2]|0)+',0.9)'; ctx.shadowBlur=rblur*inten; ctx.strokeStyle='rgba('+(rc[0]|0)+','+(rc[1]|0)+','+(rc[2]|0)+','+(rsa*inten*briMul)+')'; ctx.lineWidth=Math.max(1.2,Re*0.03);
      { const _pres=Math.max(0,Math.min(1,(vLev-4)/4)); const act=Math.max(chargeE,boom*0.6,_pres); if(act<0.03){ ctx.beginPath(); ctx.arc(camCx,camCy,Re*1.02,0,6.2832); } else { const amp=act*0.006, step=Math.floor(time*15), seg=56; ctx.beginPath(); for(let i=0;i<=seg;i++){ const th=i/seg*6.2832; const hh=Math.sin(i*12.9898+step*78.233)*43758.5453; const jit=hh-Math.floor(hh); const rr=Re*1.02*(1+(jit-0.5)*2*amp); const x=camCx+Math.cos(th)*rr, y=camCy+Math.sin(th)*rr; if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y); } ctx.closePath(); } } ctx.stroke(); ctx.restore();
      // charge glow burst
      if(chargeE>0.01||boom>0.01){ ctx.globalCompositeOperation='lighter'; const tt=Math.min(1,chargeE); const g0=[150,205,255],g1=[255,150,70]; const gc=[g0[0]+(g1[0]-g0[0])*tt,g0[1]+(g1[1]-g0[1])*tt,g0[2]+(g1[2]-g0[2])*tt]; const pulse=1+0.18*Math.sin(time*(7+chargeE*12)); const base=Re*(0.8+1.9*chargeE)*pulse+boom*Re*3.2; const gg=ctx.createRadialGradient(camCx,camCy,0,camCx,camCy,base); gg.addColorStop(0,'rgba(255,255,255,'+Math.min(0.92,(0.5*chargeE+boom))+')'); gg.addColorStop(0.35,'rgba('+(gc[0]|0)+','+(gc[1]|0)+','+(gc[2]|0)+','+((0.4*chargeE+boom*0.5)*inten)+')'); gg.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=gg; ctx.beginPath(); ctx.arc(camCx,camCy,base,0,6.2832); ctx.fill(); }
      drawOrbits(false); drawParts(false); drawParts(false,energyParts,energy); drawBurst();
      ctx.globalCompositeOperation='source-over';
    }

    let raf=null,last=performance.now();
    function loop(now){ const dt=Math.min(.05,(now-last)/1000); last=now; render(dt,now/1000); raf=requestAnimationFrame(loop); }
    resize();
    function onResize(){ resize(); }
    function onMove(e){ mx=e.clientX; my=e.clientY; hover=true; }
    function onLeave(){ hover=false; mx=-9999; my=-9999; }
    window.addEventListener('resize',onResize);
    if(!reduce){ window.addEventListener('pointermove',onMove); window.addEventListener('pointerleave',onLeave); }
    renderText(0);
    render(0.016,performance.now()/1000);
    if(reduce){ window.addEventListener('scroll',()=>{ render(.2,performance.now()/1000); },{passive:true}); }
    else { raf=requestAnimationFrame(loop); }
    return {
      stop(){ if(raf)cancelAnimationFrame(raf); window.removeEventListener('resize',onResize); window.removeEventListener('pointermove',onMove); window.removeEventListener('pointerleave',onLeave); },
      resetForCache(){ renderText(0); ctx.clearRect(0, 0, w, h); }
    };
  }
}
