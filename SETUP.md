# SERVMAC Tracker — Setup Supabase + Despliegue

Esta guía deja la app funcionando en producción con **Supabase** (base de datos + auth + storage + realtime) y **Vercel** (hosting) en menos de 1 día.

---

## 1. Crear proyecto Supabase (10 min)

1. Ve a [supabase.com](https://supabase.com) → **Start your project** (sign in con GitHub o Google)
2. **New project**
   - Name: `servmac-tracker`
   - Database password: genera una fuerte y guárdala
   - Region: `us-east-1` o `mx-central-1` (más cercano)
   - Plan: **Free** (sirve para arrancar)
3. Espera ~2 min mientras se aprovisiona
4. **Settings → API**, copia:
   - `Project URL` → ej. `https://abcdefgh.supabase.co`
   - `anon public` key (sí, esta es segura para frontend)
   - `service_role` key (esta NO la expongas, sólo para el add-on de Gmail)

---

## 2. Crear las tablas (5 min)

1. En Supabase: **SQL Editor → New query**
2. Pega completo el contenido de `supabase/schema.sql`
3. Click **Run** — debe terminar sin errores
4. Verifica en **Table Editor** que existan las 24 tablas

---

## 3. Crear los buckets de Storage (3 min)

En **Storage → New bucket**, crea estos 4:

| Bucket | Público | Uso |
|---|---|---|
| `proyecto-fotos` | ✅ Sí | Fotos de bitácora |
| `proyecto-docs` | ❌ No | Actas, planos, carpeta cierre |
| `facturas-xml` | ❌ No | CFDI XML/PDF |
| `proveedor-docs` | ❌ No | RFC, NSS, CURP, INE de proveedores |

---

## 4. Habilitar Auth con Google (5 min)

1. **Authentication → Providers → Google**
2. En Google Cloud Console crea OAuth credentials:
   - APIs & Services → Credentials → Create → OAuth client ID
   - Application type: Web
   - Authorized redirect URIs: pega la "Callback URL" que Supabase te muestra
3. Copia **Client ID** y **Client Secret** en Supabase y activa
4. Restringe a dominio `@servmac.mx` si quieres (URL Configuration → Site URL)

---

## 5. Conectar la app (10 min)

1. Edita `supabase/api.js`:
   ```js
   const SUPABASE_URL      = 'https://abcdefgh.supabase.co';
   const SUPABASE_ANON_KEY = 'tu_anon_key_aqui';
   ```

2. En `SERVMAC Tracker.html`, **antes** de `data.js` agrega:
   ```html
   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
   <script src="supabase/api.js"></script>
   ```

3. Reemplaza `<script src="data.js"></script>` por un loader async (al inicio del `<body>`):
   ```html
   <script>
     (async () => {
       const user = await SB_AUTH.currentUser();
       if (!user) { window.location.href = 'login.html'; return; }
       await SB_LOAD_ALL();
       SB_SUBSCRIBE_ALL();
     })();
   </script>
   ```

4. Migra los datos mockeados (una sola vez):
   - Abre la app en el navegador con la consola
   - Pega `supabase/migrate-mock-to-supabase.js` en la consola
   - Ejecuta `migrate()` y espera el ✓

---

## 6. Conectar el Add-on de Gmail

En tu Apps Script existente, agrega un endpoint que escriba a Supabase:

```js
function clasificarYEnviar(emailData) {
  const intencion = clasificarConClaude(emailData);  // tu lógica actual

  const payload = {
    proyecto_id: emailData.proyectoId,    // CR detectado
    remitente: emailData.from,
    asunto: emailData.subject,
    preview: emailData.body.substring(0, 500),
    fecha: new Date().toISOString().slice(0,10),
    tipo: emailData.tipo,                  // correo cliente | WhatsApp
    intencion: intencion.tipo,
    accion: intencion.accionSugerida,
    confianza: intencion.confianza,
    estatus: 'nuevo',
    link_gmail: emailData.threadUrl,
    raw: emailData,
  };

  UrlFetchApp.fetch('https://abcdefgh.supabase.co/rest/v1/inbox', {
    method: 'post',
    headers: {
      'apikey': SUPABASE_SERVICE_KEY,   // service_role (NO la anon)
      'Authorization': 'Bearer ' + SUPABASE_SERVICE_KEY,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    payload: JSON.stringify(payload),
  });
}
```

Cada vez que llega un correo, aparece en la bandeja del add-on de la app **en tiempo real** gracias a la suscripción realtime.

---

## 7. Desplegar en Vercel (15 min)

1. Sube el proyecto a GitHub:
   ```bash
   git init
   git add .
   git commit -m "SERVMAC Tracker v1"
   git remote add origin https://github.com/TU_USUARIO/servmac-tracker.git
   git push -u origin main
   ```

2. Ve a [vercel.com](https://vercel.com) → Sign in con GitHub
3. **New Project** → importar tu repo
4. Framework Preset: **Other** (es HTML estático)
5. Click **Deploy** — listo en 30 segundos
6. Te da una URL tipo `servmac-tracker.vercel.app`

### Dominio custom
1. En Vercel → Settings → Domains
2. Add → `tracker.servmac.mx`
3. Configura DNS:
   - Tipo `CNAME`
   - Host `tracker`
   - Valor `cname.vercel-dns.com`
4. Vercel detecta el cambio en ~5 min y emite SSL automático

---

## 8. Rate limits / costos

| Recurso | Plan Free | Plan Pro ($25/mes) |
|---|---|---|
| Base de datos | 500 MB | 8 GB |
| Storage | 1 GB | 100 GB |
| Bandwidth | 5 GB | 250 GB |
| Auth users | 50,000 MAU | 100,000 MAU |
| Realtime conexiones | 200 | 500 |

Con tus 68 proyectos actuales y crecimiento esperado de SERVMAC, el plan **Free** te aguanta 6-12 meses.

---

## 9. Roadmap de adopción sugerido

| Semana | Acción |
|---|---|
| 1 | Setup Supabase + migración + desplegar en vercel.app |
| 2 | Pruebas con tu equipo en `tracker.servmac.mx` |
| 3 | Conectar add-on Gmail → tabla `inbox` |
| 4 | Ajustes finos: roles, permisos por persona |
| 5+ | Operación normal con todo el equipo |

---

## 10. Backups y seguridad

- **Backups automáticos:** Supabase los hace cada 24h en plan Pro. En Free puedes exportar manualmente desde Database → Backups.
- **Row Level Security:** ya está habilitada en el schema. Cualquier usuario autenticado puede leer y escribir. Si quieres restringir DELETE a admin:
  ```sql
  drop policy "auth_write_proyectos" on proyectos;
  create policy "rw_proyectos" on proyectos for select, insert, update to authenticated using (true);
  create policy "del_admin_proyectos" on proyectos for delete to authenticated using (
    exists (select 1 from personas_servmac where email = auth.email() and rol = 'Dirección')
  );
  ```
- **API keys:**
  - `anon` key → puede ir en el frontend (ya tiene RLS)
  - `service_role` key → SOLO en el add-on Gmail (server-side)

---

## Contacto / soporte

Si te atoras en algún paso, abre [supabase.com/docs](https://supabase.com/docs) o el Discord de Supabase. La documentación es excelente y la comunidad responde rápido.
