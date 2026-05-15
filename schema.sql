-- =====================================================================
-- SERVMAC Tracker — Schema Supabase (PostgreSQL)
-- =====================================================================
-- Ejecuta este archivo completo en Supabase: SQL Editor → New query →
-- pegar todo → Run. Crea las 17 tablas, índices, RLS y triggers.
-- =====================================================================

-- Extensiones útiles
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =====================================================================
-- TABLAS MAESTRAS / CATÁLOGOS
-- =====================================================================

create table if not exists personas_servmac (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  rol text,
  email text unique,
  telefono text,
  activo boolean default true,
  created_at timestamptz default now()
);

create table if not exists personas_cliente (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  empresa text,
  rol text,
  email text,
  telefono text,
  activo boolean default true,
  created_at timestamptz default now()
);

create table if not exists proveedores (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  rfc text,
  id_empresa text,
  nss text,
  curp text,
  ine text,
  especialidad text,
  region text,
  rating numeric(3,1) default 4.0,
  telefono text,
  email text,
  direccion text,
  docs jsonb default '{}'::jsonb,    -- {RFC, CSF, INE, NSS, CURP, Estado_cuenta}
  activo boolean default true,
  created_at timestamptz default now()
);

create table if not exists proveedor_equipos (
  id uuid primary key default gen_random_uuid(),
  proveedor_id uuid references proveedores(id) on delete cascade,
  nombre text not null,
  integrantes int default 0,
  lider text
);

-- =====================================================================
-- PROYECTOS (tabla central)
-- =====================================================================

create table if not exists proyectos (
  id uuid primary key default gen_random_uuid(),
  -- Identificación
  cr text,
  tipo text,
  asignacion text,
  region text,
  sucursal text not null,
  proyecto text,
  descripcion text,
  tipologia text,
  tipo_preciario text,
  anio_asignacion int,
  -- Códigos
  codigo_uda text,
  codigo_compras text,
  contrato text,
  orden_compra text,
  anexo text,
  anexo_obra text,
  enlace_contrato text,
  enlace_contrato_firmado text,
  enlace_cierre_drive text,
  -- Ubicación
  direccion text,
  estado text,
  cp text,
  lat numeric(9,6),
  lng numeric(9,6),
  maps_url text,
  -- Equipo
  persona_servmac_id uuid references personas_servmac(id),
  persona_cliente_id uuid references personas_cliente(id),
  persona_detonadora text,
  supervisor text,
  -- Fechas
  fecha_asignacion date,
  fecha_inicio_prog date,
  fecha_termino_prog date,
  fecha_meta date,
  fecha_recepcion_contrato date,
  fecha_firma_interna date,
  fecha_envio_certificacion date,
  fecha_acta_inicio date,
  fecha_acta_cierre date,
  fecha_envio_cierre date,
  -- Importes
  importe_contratado numeric(14,2) default 0,
  importe_accion numeric(14,2) default 0,
  importe_certificacion numeric(14,2) default 0,
  importe_limite_penalizacion numeric(14,2) default 0,
  importe_cierre_enviado numeric(14,2) default 0,
  importe_cierre_aceptado numeric(14,2),
  importe_cfe numeric(14,2) default 0,
  -- Estatus
  estatus text default '05. Gestion por iniciar Obra',
  sub_estatus text,
  entregable text,
  estatus_operativo text,
  estatus_cierre text,
  estatus_certificacion text,
  estatus_firma text,
  tipo_bloqueo text default 'Sin bloqueo',
  num_factura text,
  formato_cierre text,
  aplica_penalizacion boolean default false,
  aplica_fin47 boolean default false,
  observaciones text,
  activo boolean default true,
  -- Audit
  created_by uuid references personas_servmac(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists ix_proyectos_estatus on proyectos(estatus);
create index if not exists ix_proyectos_persona on proyectos(persona_servmac_id);
create index if not exists ix_proyectos_region on proyectos(region);

-- =====================================================================
-- TABLAS DEPENDIENTES DE PROYECTO
-- =====================================================================

create table if not exists snapshots (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  semana text not null,             -- "S2 may 2026"
  fecha_corte date,
  estatus text,
  sub_estatus text,
  documentacion text,
  entregable text,
  fecha_meta date,
  comentarios text,
  carry_forward boolean default false,
  cambio_estatus boolean default false,
  created_at timestamptz default now()
);
create index if not exists ix_snapshots_proyecto on snapshots(proyecto_id);

create table if not exists hitos (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  tipo text not null,               -- Acta inicio | Acta final | Certificación | Puesta operación | Carpeta cierre | Pago
  fecha_programada date,
  fecha_real date,
  estatus text default 'pendiente', -- pendiente | cumplido | atrasado
  link text,
  responsable_id uuid references personas_servmac(id),
  created_at timestamptz default now()
);

create table if not exists comunicaciones (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  fecha date,
  tipo text,                        -- correo cliente | correo SERVMAC | WhatsApp | junta
  resumen text,
  origen text,
  destino text,
  link_gmail text,
  created_at timestamptz default now()
);

-- Cronograma editable por proyecto
create table if not exists fases (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  nombre text not null,
  color text default '#1E40AF',
  inicio date,
  fin date,
  orden int default 0
);

create table if not exists tareas (
  id uuid primary key default gen_random_uuid(),
  fase_id uuid references fases(id) on delete cascade,
  nombre text not null,
  from_pct numeric(5,2) default 0,
  to_pct numeric(5,2) default 100,
  hito_tipo text,
  critica boolean default false,
  orden int default 0
);

-- Plan vs Real
create table if not exists plan_actividades (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  nombre text not null,
  fase text,                        -- Gestión | En obra | Cierre
  peso int default 5,
  critica boolean default false,
  planned_start date,
  planned_end date,
  real_start date,
  real_end date,
  avance int default 0
);

-- Validador de avances
create table if not exists validaciones (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  tarea text not null,
  peso int default 10,
  programado_pct int default 0,
  real_pct int default 0,
  estatus text default 'en tiempo',
  validado_por uuid references personas_servmac(id),
  fecha_validacion date,
  evidencia int default 0
);

-- Bitácora de obra
create table if not exists bitacora (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  fecha date not null,
  autor text,
  avance_pct int default 0,
  clima text,
  personal int default 0,
  descripcion text,
  incidencias text,
  siguiente text,
  fotos_count int default 0,
  created_at timestamptz default now()
);

-- Revisiones de equipo
create table if not exists revisiones (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  numero int,
  fecha date,
  avance_estimado int,
  avance_real int,
  participantes text[],
  resultado text,                   -- en tiempo | con observaciones | crítico
  notas text,
  acuerdos text
);

-- Bugs / bloqueos
create table if not exists bugs (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  titulo text not null,
  severidad text default 'media',   -- baja | media | alta
  categoria text,                   -- operativo | administrativo | bloqueo | financiero
  responsable text,
  fecha_detectado date default current_date,
  estatus text default 'abierto',
  impacto_dias int default 0,
  descripcion text
);

-- HSE
create table if not exists incidentes_hse (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  fecha date,
  tipo text,
  severidad text,
  descripcion text,
  accion_correctiva text,
  responsable text,
  estatus text default 'abierto',
  afectados int default 0,
  horas_perdidas numeric(5,2) default 0
);

-- Comentarios / hilo del proyecto
create table if not exists comentarios (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  autor_id uuid references personas_servmac(id),
  autor_nombre text,
  texto text not null,
  fijado boolean default false,
  created_at timestamptz default now()
);

-- Activity log
create table if not exists actividad_log (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  tipo text,                        -- creacion | asignacion | hito | financiero | visita | archivo | bloqueo | comentario
  texto text,
  autor text,
  fecha date default current_date,
  meta jsonb,
  created_at timestamptz default now()
);

-- =====================================================================
-- FINANZAS
-- =====================================================================

create table if not exists finanzas (
  proyecto_id uuid primary key references proyectos(id) on delete cascade,
  fianza jsonb default '{}'::jsonb,
  anticipo jsonb default '{}'::jsonb,
  retencion jsonb default '{}'::jsonb,
  totales jsonb default '{}'::jsonb,
  updated_at timestamptz default now()
);

create table if not exists pagos (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  fecha date,
  tipo text,                        -- Anticipo | Estimación 1 | ... | Liberación de retención
  monto numeric(14,2),
  referencia text,
  prefactura text,
  estatus text default 'pendiente cobro',
  metodo text default 'Transferencia SPEI',
  comentario text
);

create table if not exists facturas (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  proveedor_id uuid references proveedores(id),
  folio text,
  fecha date,
  concepto text,
  tipo text,                        -- material | servicio | subcontrato | mano de obra
  subtotal numeric(14,2),
  iva numeric(14,2),
  total numeric(14,2),
  forma_pago text,
  estatus_pago text default 'pendiente',
  fecha_pago date,
  xml_url text,
  pdf_url text
);

create table if not exists materiales (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  descripcion text,
  unidad text,
  cantidad numeric(10,2),
  costo_unit numeric(12,2),
  total numeric(14,2),
  proveedor text,
  factura_id uuid references facturas(id),
  estatus text,
  fecha date
);

create table if not exists proyecto_proveedores (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  proveedor_id uuid references proveedores(id),
  equipo_id uuid references proveedor_equipos(id),
  scope text,
  rol text,
  importe numeric(14,2),
  importe_pagado numeric(14,2) default 0,
  inicio date,
  fin date,
  estatus text default 'iniciando'
);

-- =====================================================================
-- CIERRE ADMINISTRATIVO - CHECKLIST
-- =====================================================================

create table if not exists cierre_checklist (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  clave text,
  etiqueta text,
  cargado boolean default false,
  porcentaje int default 0,
  fecha date,
  comentario text,
  orden int default 0
);

-- =====================================================================
-- INBOX / ADD-ON GMAIL
-- =====================================================================

create table if not exists inbox (
  id uuid primary key default gen_random_uuid(),
  proyecto_id uuid references proyectos(id) on delete cascade,
  remitente text,
  asunto text,
  preview text,
  fecha date,
  tipo text,                        -- correo cliente | correo SERVMAC | WhatsApp | junta
  intencion text,                   -- cita_solicitada | documento_entregar | firma_solicitada | ...
  accion text,
  confianza numeric(3,2),
  estatus text default 'nuevo',     -- nuevo | sugerido | procesado | ignorado
  adjuntos int default 0,
  link_gmail text,
  raw jsonb,
  created_at timestamptz default now()
);
create index if not exists ix_inbox_estatus on inbox(estatus);
create index if not exists ix_inbox_proyecto on inbox(proyecto_id);

-- =====================================================================
-- PLANTILLAS
-- =====================================================================

create table if not exists plantillas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  icono text,
  descripcion text,
  duracion_dias int,
  color text default '#1E40AF',
  veces_usada int default 0,
  fases jsonb default '[]'::jsonb,  -- estructura completa de fases + tareas + hitos
  created_at timestamptz default now()
);

-- =====================================================================
-- STORAGE BUCKETS (crear desde la UI: Storage → New bucket)
-- =====================================================================
-- bucket: proyecto-fotos    (público)   — fotos de bitácora
-- bucket: proyecto-docs     (privado)   — actas, planos, carpeta de cierre
-- bucket: facturas-xml      (privado)   — CFDI XML y PDF
-- bucket: proveedor-docs    (privado)   — RFC, NSS, CURP, INE de proveedores

-- =====================================================================
-- TRIGGERS — updated_at automático
-- =====================================================================

create or replace function set_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger trg_proyectos_updated before update on proyectos
  for each row execute function set_updated_at();
create trigger trg_finanzas_updated before update on finanzas
  for each row execute function set_updated_at();

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
-- Cada usuario autenticado puede leer todo, y escribir/modificar
-- proyectos donde aparezca como persona_servmac. Dirección ve todo.
-- Ajusta a tus reglas internas.

alter table proyectos       enable row level security;
alter table snapshots       enable row level security;
alter table hitos           enable row level security;
alter table comunicaciones  enable row level security;
alter table fases           enable row level security;
alter table tareas          enable row level security;
alter table plan_actividades enable row level security;
alter table validaciones    enable row level security;
alter table bitacora        enable row level security;
alter table revisiones      enable row level security;
alter table bugs            enable row level security;
alter table incidentes_hse  enable row level security;
alter table comentarios     enable row level security;
alter table actividad_log   enable row level security;
alter table finanzas        enable row level security;
alter table pagos           enable row level security;
alter table facturas        enable row level security;
alter table materiales      enable row level security;
alter table proyecto_proveedores enable row level security;
alter table cierre_checklist enable row level security;
alter table inbox           enable row level security;
alter table plantillas      enable row level security;
alter table proveedores     enable row level security;
alter table proveedor_equipos enable row level security;
alter table personas_servmac enable row level security;
alter table personas_cliente enable row level security;

-- Policy global de LECTURA para cualquier usuario autenticado
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('drop policy if exists "auth_read_%I" on %I', t, t);
    execute format('create policy "auth_read_%I" on %I for select to authenticated using (true)', t, t);
  end loop;
end$$;

-- Policy global de ESCRITURA para cualquier usuario autenticado
-- (afina después: por ejemplo, restringir DELETE sólo a admin)
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('drop policy if exists "auth_write_%I" on %I', t, t);
    execute format('create policy "auth_write_%I" on %I for all to authenticated using (true) with check (true)', t, t);
  end loop;
end$$;
