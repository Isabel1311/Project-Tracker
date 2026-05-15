// =====================================================================
// SERVMAC Tracker — Cliente Supabase
// =====================================================================
// Cómo usar:
// 1. En supabase.com, crea proyecto → Settings → API:
//    copia "URL" y "anon public" key
// 2. Pega abajo en SUPABASE_URL y SUPABASE_ANON_KEY
// 3. Carga el SDK desde CDN en tu HTML antes de este archivo:
//    <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
// 4. Reemplaza window.SERVMAC_DATA y window.SERVMAC_EXTRAS con
//    llamadas a SB.proyectos.list(), etc.
// =====================================================================

const SUPABASE_URL      = 'https://TU_PROYECTO.supabase.co';
const SUPABASE_ANON_KEY = 'TU_ANON_KEY_AQUI';

window.sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true },
  realtime: { params: { eventsPerSecond: 10 } },
});

// =====================================================================
// AUTENTICACIÓN
// =====================================================================
window.SB_AUTH = {
  async loginGoogle() {
    const { error } = await window.sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin + window.location.pathname }
    });
    if (error) throw error;
  },
  async loginEmail(email, password) {
    const { data, error } = await window.sb.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data.user;
  },
  async logout() { await window.sb.auth.signOut(); },
  async currentUser() {
    const { data } = await window.sb.auth.getUser();
    return data?.user;
  },
};

// =====================================================================
// CRUD genérico — usa para cualquier tabla
// =====================================================================
function crud(table) {
  return {
    async list(filter = {}) {
      let q = window.sb.from(table).select('*');
      Object.entries(filter).forEach(([k, v]) => { q = q.eq(k, v); });
      const { data, error } = await q;
      if (error) throw error;
      return data;
    },
    async get(id) {
      const { data, error } = await window.sb.from(table).select('*').eq('id', id).single();
      if (error) throw error;
      return data;
    },
    async insert(row) {
      const { data, error } = await window.sb.from(table).insert(row).select().single();
      if (error) throw error;
      return data;
    },
    async update(id, patch) {
      const { data, error } = await window.sb.from(table).update(patch).eq('id', id).select().single();
      if (error) throw error;
      return data;
    },
    async delete(id) {
      const { error } = await window.sb.from(table).delete().eq('id', id);
      if (error) throw error;
    },
    // Suscripción en tiempo real
    subscribe(callback) {
      return window.sb.channel(`realtime-${table}`)
        .on('postgres_changes', { event: '*', schema: 'public', table }, callback)
        .subscribe();
    },
  };
}

// =====================================================================
// API por entidad
// =====================================================================
window.SB = {
  proyectos:     crud('proyectos'),
  snapshots:     crud('snapshots'),
  hitos:         crud('hitos'),
  comunicaciones: crud('comunicaciones'),
  fases:         crud('fases'),
  tareas:        crud('tareas'),
  plan_actividades: crud('plan_actividades'),
  validaciones:  crud('validaciones'),
  bitacora:      crud('bitacora'),
  revisiones:    crud('revisiones'),
  bugs:          crud('bugs'),
  incidentes_hse: crud('incidentes_hse'),
  comentarios:   crud('comentarios'),
  actividad_log: crud('actividad_log'),
  finanzas:      crud('finanzas'),
  pagos:         crud('pagos'),
  facturas:      crud('facturas'),
  materiales:    crud('materiales'),
  proyecto_proveedores: crud('proyecto_proveedores'),
  cierre_checklist: crud('cierre_checklist'),
  inbox:         crud('inbox'),
  plantillas:    crud('plantillas'),
  proveedores:   crud('proveedores'),
  personas_servmac: crud('personas_servmac'),
  personas_cliente: crud('personas_cliente'),
};

// =====================================================================
// STORAGE (fotos, PDFs, XML)
// =====================================================================
window.SB_STORAGE = {
  async subirFoto(file, proyectoId, prefix = 'bitacora') {
    const path = `${proyectoId}/${prefix}/${Date.now()}_${file.name}`;
    const { error } = await window.sb.storage.from('proyecto-fotos').upload(path, file);
    if (error) throw error;
    const { data } = window.sb.storage.from('proyecto-fotos').getPublicUrl(path);
    return data.publicUrl;
  },
  async subirCFDI(xmlFile, pdfFile, proyectoId, folio) {
    const xmlPath = `${proyectoId}/${folio}.xml`;
    const pdfPath = `${proyectoId}/${folio}.pdf`;
    await window.sb.storage.from('facturas-xml').upload(xmlPath, xmlFile, { upsert: true });
    await window.sb.storage.from('facturas-xml').upload(pdfPath, pdfFile, { upsert: true });
    return { xml: xmlPath, pdf: pdfPath };
  },
  async firmarUrl(bucket, path, segundos = 3600) {
    const { data, error } = await window.sb.storage.from(bucket).createSignedUrl(path, segundos);
    if (error) throw error;
    return data.signedUrl;
  },
};

// =====================================================================
// CARGA INICIAL — al arrancar la app, llenar window.SERVMAC_DATA
// =====================================================================
window.SB_LOAD_ALL = async function() {
  console.log('[Supabase] Cargando datos...');
  const [proyectos, snapshots, hitos, comunicaciones, financiero] = await Promise.all([
    window.SB.proyectos.list(),
    window.SB.snapshots.list(),
    window.SB.hitos.list(),
    window.SB.comunicaciones.list(),
    window.SB.finanzas.list(),
  ]);
  window.SERVMAC_DATA = {
    proyectos, snapshots, hitos, comunicaciones, financiero,
    weeks: [...new Set(snapshots.map(s => s.semana))].sort(),
    today: new Date().toISOString().slice(0,10),
  };
  console.log('[Supabase] ✓ ' + proyectos.length + ' proyectos cargados');
};

// =====================================================================
// SUSCRIPCIÓN REALTIME — escucha cambios y actualiza la UI
// =====================================================================
window.SB_SUBSCRIBE_ALL = function() {
  ['proyectos','hitos','comentarios','pagos','inbox'].forEach(t => {
    window.SB[t].subscribe(payload => {
      console.log('[Realtime]', t, payload.eventType);
      window.SB_LOAD_ALL().then(() => window.SERVMAC_RERENDER?.());
    });
  });
};
