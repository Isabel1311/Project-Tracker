// =====================================================================
// Migración: del mock en memoria (data.js / extras.js) a Supabase
// =====================================================================
// Cómo correr:
// 1. Abre tu app en el navegador con la consola abierta
// 2. Verifica que window.sb esté inicializado (api.js cargado)
// 3. Pega este archivo en la consola y ejecuta migrate()
// =====================================================================

async function migrate() {
  const D = window.SERVMAC_DATA;
  const E = window.SERVMAC_EXTRAS;
  if (!D || !E) { console.error('Falta SERVMAC_DATA o SERVMAC_EXTRAS'); return; }

  console.log('🚀 Iniciando migración a Supabase...');

  // 1. Personas SERVMAC
  console.log('Insertando personas_servmac...');
  for (const p of E.catalogos.personas_servmac) {
    await window.sb.from('personas_servmac').upsert({
      nombre: p.nombre, rol: p.rol, email: p.email, telefono: p.telefono, activo: p.activo,
    });
  }

  // 2. Personas Cliente
  console.log('Insertando personas_cliente...');
  for (const p of E.catalogos.personas_cliente) {
    await window.sb.from('personas_cliente').upsert({
      nombre: p.nombre, empresa: p.empresa, rol: p.rol, email: p.email, activo: p.activo,
    });
  }

  // 3. Proveedores
  console.log('Insertando proveedores...');
  for (const pv of E.proveedores) {
    const { data: prov } = await window.sb.from('proveedores').insert({
      nombre: pv.nombre, rfc: pv.rfc, id_empresa: pv.id_empresa, nss: pv.nss,
      curp: pv.curp, ine: pv.ine, especialidad: pv.especialidad, region: pv.region,
      rating: pv.rating, telefono: pv.telefono, email: pv.email, direccion: pv.direccion,
      docs: pv.docs || {},
    }).select().single();
    for (const eq of (pv.equipos || [])) {
      await window.sb.from('proveedor_equipos').insert({
        proveedor_id: prov.id, nombre: eq.nombre, integrantes: eq.integrantes, lider: eq.lider,
      });
    }
  }

  // 4. Proyectos (con metadatos)
  console.log('Insertando proyectos (esto tarda más)...');
  const idMap = {};
  for (const p of D.proyectos) {
    const meta = E.proyectos_meta?.[p.id] || {};
    const { data: row } = await window.sb.from('proyectos').insert({
      cr: p.cr, tipo: p.tipo, asignacion: p.asignacion, region: p.region,
      sucursal: p.sucursal, proyecto: p.proyecto, descripcion: p.descripcion,
      tipologia: meta.tipologia, tipo_preciario: meta.tipo_preciario,
      anio_asignacion: meta.anio_asignacion,
      codigo_uda: meta.codigo_uda, codigo_compras: meta.codigo_compras,
      contrato: meta.contrato, orden_compra: meta.orden_compra,
      anexo: meta.anexo, anexo_obra: meta.anexo_obra,
      direccion: meta.direccion, estado: meta.estado, cp: meta.cp, maps_url: meta.maps_url,
      fecha_asignacion: p.fecha_asignacion,
      fecha_inicio_prog: p.fecha_inicio_prog,
      fecha_termino_prog: p.fecha_termino_prog,
      fecha_meta: p.fecha_meta,
      importe_contratado: p.importe_contratado,
      importe_accion: meta.importe_accion,
      importe_certificacion: meta.importe_certificacion,
      importe_limite_penalizacion: meta.importe_limite_penalizacion,
      importe_cierre_enviado: meta.importe_cierre_enviado,
      importe_cierre_aceptado: meta.importe_cierre_aceptado,
      importe_cfe: meta.importe_cfe,
      estatus: p.estatus, sub_estatus: p.sub_estatus, entregable: p.entregable,
      estatus_operativo: meta.estatus_operativo, estatus_cierre: meta.estatus_cierre,
      estatus_certificacion: meta.estatus_certificacion, estatus_firma: meta.estatus_firma,
      tipo_bloqueo: meta.tipo_bloqueo, num_factura: meta.num_factura,
      formato_cierre: meta.formato_cierre,
      aplica_penalizacion: meta.aplica_penalizacion, aplica_fin47: meta.aplica_fin47,
      activo: p.activo,
    }).select().single();
    idMap[p.id] = row.id;
  }

  // 5. Snapshots, Hitos, Comunicaciones
  console.log('Insertando snapshots...');
  for (const s of D.snapshots) {
    await window.sb.from('snapshots').insert({
      proyecto_id: idMap[s.id_proyecto], semana: s.semana, fecha_corte: s.fecha_corte,
      estatus: s.estatus, sub_estatus: s.sub_estatus, documentacion: s.documentacion,
      entregable: s.entregable, fecha_meta: s.fecha_meta, comentarios: s.comentarios,
    });
  }
  console.log('Insertando hitos...');
  for (const h of D.hitos) {
    await window.sb.from('hitos').insert({
      proyecto_id: idMap[h.id_proyecto], tipo: h.tipo,
      fecha_programada: h.fecha_programada, fecha_real: h.fecha_real,
      estatus: h.estatus, link: h.link,
    });
  }
  console.log('Insertando comunicaciones...');
  for (const c of D.comunicaciones) {
    await window.sb.from('comunicaciones').insert({
      proyecto_id: idMap[c.id_proyecto], fecha: c.fecha, tipo: c.tipo,
      resumen: c.resumen, origen: c.origen, destino: c.destino, link_gmail: c.link,
    });
  }

  // 6. Finanzas y pagos
  console.log('Insertando finanzas...');
  for (const [pid, f] of Object.entries(E.finanzas)) {
    if (!idMap[pid]) continue;
    await window.sb.from('finanzas').upsert({
      proyecto_id: idMap[pid],
      fianza: f.fianza, anticipo: f.anticipo, retencion: f.retencion, totales: f.totales,
    });
    for (const pg of f.pagos) {
      await window.sb.from('pagos').insert({
        proyecto_id: idMap[pid], fecha: pg.fecha, tipo: pg.tipo,
        monto: pg.monto, referencia: pg.referencia, prefactura: pg.prefactura,
        estatus: pg.estatus, metodo: pg.metodo, comentario: pg.comentario,
      });
    }
  }

  console.log('✓ Migración completa. Revisa Supabase Table Editor.');
}

window.migrate = migrate;
