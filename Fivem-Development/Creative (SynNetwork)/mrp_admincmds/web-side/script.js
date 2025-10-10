// =====================
// Clipboard bridge + Router
// =====================
(function(){
  function legacyCopy(text){
    try{
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly','');
      ta.style.position = 'absolute';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    }catch(e){ return false; }
  }

  async function modernCopy(text){
    try{
      if (navigator.clipboard && navigator.clipboard.writeText){
        await navigator.clipboard.writeText(text);
        return true;
      }
      return legacyCopy(text);
    }catch(e){ return legacyCopy(text); }
  }

  // Recebe mensagens do client (abrir UI / copiar texto)
  window.addEventListener('message', async (event)=>{
    const data = event.data || {};

    // Ação de copiar (vinda de exports.Copy ou dos botões)
    if (data.action === 'copy' && typeof data.text === 'string'){
      const ok = await modernCopy(data.text);
      try{
        fetch(`https://${GetParentResourceName()}/copied`, {
          method: 'POST',
          headers: { 'Content-Type':'application/json; charset=UTF-8' },
          body: JSON.stringify({ ok, text: data.text })
        });
      }catch(e){}
      return;
    }

    // Abrir UI (payload com outfit/luaBlock/jsonBlock)
    if (data.action === 'open' && data.payload){
      openUI(data.payload);
    }
  });

  // Helper global opcional para copiar manualmente do front-end
  window.synCopyToClipboard = async function(text){
    window.postMessage({ action:'copy', text }, '*');
  };
})();

// =====================
// UI logic (única versão)
// =====================
(function(){
  const app      = document.getElementById('app');
  const genderEl = document.getElementById('gender');
  const cardsEl  = document.getElementById('cards');
  const luaEl    = document.getElementById('luaBlock');
  const jsonEl   = document.getElementById('jsonBlock');

  const btnClose    = document.getElementById('btnClose');
  const btnCopyLua  = document.getElementById('btnCopyLua');
  const btnCopyJSON = document.getElementById('btnCopyJSON');

  // Labels no formato Skinshop (mais úteis p/ ti)
  const LABELS = {
    legs:'pants', shoes:'shoes', mask:'mask', tshirt:'tshirt', torso:'torso', arms:'arms',
    vest:'vest', backpack:'backpack', accessory:'accessory', decals:'decals',
    hat:'hat', glass:'glass', ear:'ear', watch:'watch', bracelet:'bracelet'
  };

  function kv(label, data){
    const wrap = document.createElement('div');
    wrap.className = 'card';
    wrap.innerHTML = `<h3>${label}</h3>
      <div class="kv">
        <span><b>item:</b> ${data.item ?? data[0] ?? 0}</span>
        <span><b>texture:</b> ${data.texture ?? data[1] ?? 0}</span>
      </div>`;
    return wrap;
  }

  function fillCards(outfit){
    cardsEl.innerHTML = '';

    // Map do snapshot original -> nomes Skinshop
    const map = {
      legs: outfit.legs, shoes: outfit.shoes, mask: outfit.masks, tshirt: outfit.undershirts,
      torso: outfit.tops, arms: outfit.torsos, vest: outfit.bodyArmors, backpack: outfit.bags,
      accessory: outfit.accessories, decals: outfit.decals,
      hat: outfit.hats, glass: outfit.glasses, ear: outfit.ears, watch: outfit.watches, bracelet: outfit.bracelets
    };

    // Normaliza para {item, texture}
    for (const [label, val] of Object.entries(map)){
      let data;
      if (Array.isArray(val)){ // [draw,tex,pal] ou [draw,tex]
        data = { item: Number(val[0]||0), texture: Number(val[1]||0) };
        // Props retirados (draw = -1) devem ter texture 0
        if (label==='hat' || label==='glass' || label==='ear' || label==='watch' || label==='bracelet'){
          if (Number(val[0]) === -1) data.texture = 0;
        }
      }else{
        data = { item: Number(val?.item||0), texture: Number(val?.texture||0) };
      }
      const readable = LABELS[label] || label;
      cardsEl.appendChild(kv(readable, data));
    }
  }

  // Exposto globalmente para o router acima
  window.openUI = function(payload){
    try{
      app.classList.remove('hide');
      genderEl.textContent = payload.outfit && payload.outfit.gender ? payload.outfit.gender : '-';

      fillCards(payload.outfit || {});

      luaEl.textContent  = payload.luaBlock  || '';
      jsonEl.textContent = payload.jsonBlock || '';
    }catch(e){}
  };

  function closeUI(){
    app.classList.add('hide');
    try{
      fetch(`https://${GetParentResourceName()}/close`, {
        method:'POST',
        headers:{'Content-Type':'application/json; charset=UTF-8'},
        body: JSON.stringify({})
      });
    }catch(e){}
  }

  // Interações
  document.addEventListener('keydown', (ev)=>{ if (ev.key === 'Escape') closeUI(); });
  if (btnClose) btnClose.addEventListener('click', closeUI);

  if (btnCopyLua){
    btnCopyLua.addEventListener('click', ()=>{
      const text = luaEl.innerText || luaEl.textContent || '';
      window.postMessage({ action:'copy', text }, '*');
    });
  }
  if (btnCopyJSON){
    btnCopyJSON.addEventListener('click', ()=>{
      const text = jsonEl.innerText || jsonEl.textContent || '';
      window.postMessage({ action:'copy', text }, '*');
    });
  }

  // Opcional: pedir snapshot ao client via NUI callback
  window.refreshFromClient = async function(){
    try{
      const res = await fetch(`https://${GetParentResourceName()}/requestOutfit`, {
        method: 'POST',
        headers: {'Content-Type':'application/json'},
        body: JSON.stringify({})
      });
      const payload = await res.json();
      window.openUI(payload);
    }catch(e){}
  };
})();
