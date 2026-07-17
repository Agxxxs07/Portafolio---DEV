-- =====================================================================
--  TALLER MECANICO - Esquema completo para Supabase (PostgreSQL)
--  Proyecto Final - Desarrollo Movil - UTP
--
--  COMO USARLO:
--    1. Supabase -> tu proyecto -> SQL Editor -> New query.
--    2. Pega TODO este archivo.
--    3. Run (Ctrl + Enter). Debe decir "Success".
--    4. Verifica en Table Editor que aparezcan las tablas.
--
--  NOTA: Login, registro, JWT y caducidad de sesion los maneja
--  Supabase Auth (tabla auth.users). Aqui NO se crea tabla de
--  usuarios ni de tokens; se extiende con la tabla "perfiles".
-- =====================================================================


-- =====================================================================
--  0. LIMPIEZA (empezar de cero)
--  Borra las tablas viejas del zip y cualquier version previa de estas.
--  El orden importa por las llaves foraneas: CASCADE se encarga.
-- =====================================================================
drop table if exists notificaciones      cascade;
drop table if exists galeria             cascade;
drop table if exists promociones         cascade;
drop table if exists config_taller       cascade;
drop table if exists fotos_servicio      cascade;
drop table if exists solicitud_tipos     cascade;
drop table if exists solicitudes_servicio cascade;
drop table if exists tipos_servicio      cascade;
drop table if exists facturas            cascade;
drop table if exists pedido_items        cascade;
drop table if exists pedidos             cascade;
drop table if exists carrito_items       cascade;
drop table if exists productos           cascade;
drop table if exists categorias          cascade;
drop table if exists vehiculos           cascade;
drop table if exists perfiles            cascade;

-- Tablas viejas del zip que ya no se usan (se reemplazan por las nuevas)
drop table if exists items_presupuesto   cascade;
drop table if exists ordenes             cascade;
drop table if exists clientes            cascade;

-- Vistas viejas
drop view if exists vista_ordenes_por_estado cascade;


-- =====================================================================
--  1. FUNCION GENERICA: actualizar timestamp
--  Se reutiliza en varias tablas para poner actualizado_en = now()
--  automaticamente cada vez que se edita una fila.
-- =====================================================================
create or replace function actualizar_timestamp()
returns trigger as $$
begin
    new.actualizado_en = now();
    return new;
end;
$$ language plpgsql;


-- =====================================================================
--  GRUPO 1: USUARIOS Y ROLES
-- =====================================================================

-- perfiles: extiende auth.users. Una fila por usuario registrado.
create table perfiles (
    id            uuid primary key references auth.users(id) on delete cascade,
    rol           text not null default 'cliente'
                  check (rol in ('cliente', 'mecanico', 'admin')),
    nombre        text not null default '',
    correo        text,
    telefono      text,
    especialidad  text,            -- solo mecanicos
    fecha_ingreso date,            -- solo mecanicos
    activo        boolean not null default true,
    creado_en     timestamptz not null default now()
);

-- Crea el perfil automaticamente cuando alguien se registra en Auth.
-- Por defecto entra como 'cliente'. Para volver a alguien mecanico:
--   update perfiles set rol = 'mecanico', especialidad = 'Motor',
--          fecha_ingreso = now() where correo = 'mecanico@correo.com';
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.perfiles (id, correo, nombre, rol)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'nombre', ''),
        'cliente'
    );
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

-- Funcion de ayuda: dice si el usuario actual es staff (mecanico/admin).
-- SECURITY DEFINER evita recursion cuando se usa dentro de las policies.
create or replace function es_staff()
returns boolean
language sql
security definer set search_path = public
stable
as $$
    select exists (
        select 1 from public.perfiles
        where id = auth.uid() and rol in ('mecanico', 'admin')
    );
$$;


-- =====================================================================
--  GRUPO 2: CATALOGO E INVENTARIO
-- =====================================================================

create table categorias (
    id     uuid primary key default gen_random_uuid(),
    nombre text not null,
    orden  int not null default 0,
    activo boolean not null default true
);

-- Esta misma tabla ES el inventario del mecanico.
create table productos (
    id            uuid primary key default gen_random_uuid(),
    categoria_id  uuid references categorias(id) on delete set null,
    nombre        text not null,
    descripcion   text default '',
    precio        numeric(10,2) not null default 0,
    stock         int not null default 0,
    umbral_stock  int not null default 20,   -- alerta "Stock Bajo" si stock <= umbral
    foto_url      text,
    destacado     boolean not null default false, -- "productos destacados" del inicio
    habilitado    boolean not null default true,  -- deshabilitar sin borrar
    creado_en     timestamptz not null default now(),
    actualizado_en timestamptz not null default now()
);

create trigger trg_ts_productos
before update on productos
for each row execute function actualizar_timestamp();


-- =====================================================================
--  GRUPO 3: CARRITO
--  Una fila por producto en el carrito de cada usuario.
--  (Los filtros y la busqueda se guardan LOCAL en el telefono, no aqui.)
-- =====================================================================
create table carrito_items (
    id          uuid primary key default gen_random_uuid(),
    usuario_id  uuid not null references perfiles(id) on delete cascade,
    producto_id uuid not null references productos(id) on delete cascade,
    cantidad    int not null default 1 check (cantidad > 0),
    agregado_en timestamptz not null default now(),
    unique (usuario_id, producto_id)
);


-- =====================================================================
--  GRUPO 4: PEDIDOS Y FACTURAS (compra de productos)
-- =====================================================================

create table pedidos (
    id            uuid primary key default gen_random_uuid(),
    usuario_id    uuid not null references perfiles(id) on delete cascade,
    estado        text not null default 'POR_ATENDER'
                  check (estado in ('POR_ATENDER','EN_PREPARACION',
                                    'LISTO_PARA_RETIRAR','ENTREGADO','CANCELADO')),
    atendido_por  uuid references perfiles(id) on delete set null, -- mecanico/admin que lo tomo primero
    subtotal      numeric(10,2) not null default 0,
    itbms         numeric(10,2) not null default 0,   -- 7%
    total         numeric(10,2) not null default 0,
    notas         text default '',
    fecha         timestamptz not null default now(),
    actualizado_en timestamptz not null default now()
);

create trigger trg_ts_pedidos
before update on pedidos
for each row execute function actualizar_timestamp();

-- Se guarda copia de nombre y precio: si el producto cambia despues,
-- la factura vieja NO debe cambiar.
create table pedido_items (
    id             uuid primary key default gen_random_uuid(),
    pedido_id      uuid not null references pedidos(id) on delete cascade,
    producto_id    uuid references productos(id) on delete set null,
    descripcion    text not null,
    cantidad       int not null default 1 check (cantidad > 0),
    precio_unitario numeric(10,2) not null default 0
);

-- Factura separada del pedido para tener el correlativo (N 0001)
-- y poder reimprimir / compartir sin recalcular.
create table facturas (
    id            uuid primary key default gen_random_uuid(),
    numero        bigint generated by default as identity unique, -- 1, 2, 3...
    pedido_id     uuid not null unique references pedidos(id) on delete cascade,
    nombre_cliente text not null default '',
    subtotal      numeric(10,2) not null default 0,
    itbms         numeric(10,2) not null default 0,
    total         numeric(10,2) not null default 0,
    fecha         timestamptz not null default now()
);


-- =====================================================================
--  GRUPO 5: VEHICULOS Y SERVICIOS (trabajos mecanicos)
-- =====================================================================

create table vehiculos (
    id          uuid primary key default gen_random_uuid(),
    cliente_id  uuid not null references perfiles(id) on delete cascade,
    placa       text not null,
    marca       text not null,
    modelo      text not null,
    anio        int,
    color       text,
    kilometraje int,
    creado_en   timestamptz not null default now()
);

-- Catalogo del checklist de servicios.
create table tipos_servicio (
    id     uuid primary key default gen_random_uuid(),
    nombre text not null,
    activo boolean not null default true
);

-- El "expediente" de una solicitud de servicio.
create table solicitudes_servicio (
    id                  uuid primary key default gen_random_uuid(),
    cliente_id          uuid not null references perfiles(id) on delete cascade,
    vehiculo_id         uuid not null references vehiculos(id) on delete cascade,
    observaciones       text default '',
    estado              text not null default 'PENDIENTE'
                        check (estado in ('PENDIENTE','CITA_PROGRAMADA',
                                          'VEHICULO_RECIBIDO','EN_REPARACION',
                                          'LISTO_PARA_ENTREGAR','ENTREGADO')),
    mecanico_id         uuid references perfiles(id) on delete set null, -- asignado
    fecha_cita          date,
    hora_cita           time,
    tiempo_estimado     text,
    fecha_entrega       date,
    comentarios_mecanico text default '',
    latitud             double precision, -- ubicacion GPS capturada en el check-in
    longitud            double precision,
    creado_en           timestamptz not null default now(),
    actualizado_en      timestamptz not null default now()
);

create trigger trg_ts_solicitudes
before update on solicitudes_servicio
for each row execute function actualizar_timestamp();

-- Relacion N:M: que servicios del checklist marco el cliente.
create table solicitud_tipos (
    solicitud_id     uuid not null references solicitudes_servicio(id) on delete cascade,
    tipo_servicio_id uuid not null references tipos_servicio(id) on delete cascade,
    primary key (solicitud_id, tipo_servicio_id)
);

-- Fotos del vehiculo y evidencia (antes / durante / despues).
create table fotos_servicio (
    id           uuid primary key default gen_random_uuid(),
    solicitud_id uuid not null references solicitudes_servicio(id) on delete cascade,
    url          text not null,
    etapa        text not null default 'INICIAL'
                 check (etapa in ('INICIAL','ANTES','DURANTE','DESPUES')),
    subida_por   uuid references perfiles(id) on delete set null,
    creado_en    timestamptz not null default now()
);

-- presupuesto_items: lineas de presupuesto (repuesto o mano de obra) de
-- una solicitud de servicio. Solo el staff las crea/edita; el cliente
-- dueno de la solicitud solo las puede leer.
create table presupuesto_items (
    id              uuid primary key default gen_random_uuid(),
    solicitud_id    uuid not null references solicitudes_servicio(id) on delete cascade,
    descripcion     text not null,
    tipo            text not null default 'REPUESTO'
                    check (tipo in ('REPUESTO', 'MANO_OBRA')),
    cantidad        numeric(10,2) not null default 1,
    precio_unitario numeric(10,2) not null default 0,
    creado_en       timestamptz not null default now()
);


-- =====================================================================
--  GRUPO 6: GESTION DEL INICIO (contenido editable por el mecanico)
-- =====================================================================

-- Una sola fila (id = 1) con todo lo editable del Inicio y Conocenos.
create table config_taller (
    id                   int primary key default 1 check (id = 1),
    nombre               text default 'Taller Mecanico XYZ',
    mensaje_bienvenida   text default '',
    resumen_conocenos    text default '',
    historia             text default '',
    mision               text default '',
    vision               text default '',
    horarios             text default '',
    telefono             text default '',
    whatsapp             text default '',
    direccion            text default '',
    latitud              double precision,
    longitud             double precision,
    imagen_principal_url text,
    actualizado_en       timestamptz not null default now()
);

create trigger trg_ts_config
before update on config_taller
for each row execute function actualizar_timestamp();

create table promociones (
    id          uuid primary key default gen_random_uuid(),
    titulo      text not null,
    descripcion text default '',
    imagen_url  text,
    precio      numeric(10,2),
    activo      boolean not null default true,
    orden       int not null default 0,
    creado_en   timestamptz not null default now()
);

create table galeria (
    id         uuid primary key default gen_random_uuid(),
    imagen_url text not null,
    titulo     text default '',
    orden      int not null default 0,
    activo     boolean not null default true
);


-- =====================================================================
--  GRUPO 7: NOTIFICACIONES
-- =====================================================================
create table notificaciones (
    id            uuid primary key default gen_random_uuid(),
    usuario_id    uuid not null references perfiles(id) on delete cascade,
    titulo        text not null,
    mensaje       text default '',
    tipo          text not null default 'PEDIDO'
                  check (tipo in ('PEDIDO','SERVICIO')),
    referencia_id uuid,   -- id del pedido o de la solicitud relacionada
    leida         boolean not null default false,
    creado_en     timestamptz not null default now()
);


-- =====================================================================
--  GRUPO 8: VISTAS PARA EL DASHBOARD (informes / graficos)
-- =====================================================================

create or replace view vista_pedidos_por_estado as
select estado, count(*) as total
from pedidos group by estado;

create or replace view vista_servicios_por_estado as
select estado, count(*) as total
from solicitudes_servicio group by estado;

create or replace view vista_ventas_por_mes as
select to_char(date_trunc('month', fecha), 'YYYY-MM') as mes,
       count(*)      as cantidad_facturas,
       sum(total)    as total_vendido
from facturas
group by 1 order by 1;

create or replace view vista_stock_bajo as
select id, nombre, stock, umbral_stock
from productos
where habilitado = true and stock <= umbral_stock
order by stock asc;

create or replace view vista_productos_mas_vendidos as
select pi.producto_id,
       pi.descripcion,
       sum(pi.cantidad) as unidades_vendidas
from pedido_items pi
group by pi.producto_id, pi.descripcion
order by unidades_vendidas desc;

-- Las vistas creadas desde el SQL Editor quedan de dueno un rol que
-- bypasea RLS por defecto. security_invoker fuerza que el RLS de las
-- tablas de abajo se evalue como el usuario que pregunta, no como el
-- dueno de la vista (si no, cualquier autenticado veria los datos de
-- TODOS los clientes al consultar estas vistas, no solo los suyos).
alter view vista_pedidos_por_estado set (security_invoker = true);
alter view vista_servicios_por_estado set (security_invoker = true);
alter view vista_ventas_por_mes set (security_invoker = true);
alter view vista_stock_bajo set (security_invoker = true);
alter view vista_productos_mas_vendidos set (security_invoker = true);


-- =====================================================================
--  9. SEGURIDAD (RLS - Row Level Security)
--  Regla general: cada cliente ve SOLO lo suyo; el staff ve TODO.
--
--  Si durante el desarrollo algo devuelve vacio y sospechas del RLS,
--  puedes desactivarlo temporalmente en una tabla con:
--     alter table nombre_tabla disable row level security;
--  y volverlo a activar cuando termines de probar.
-- =====================================================================

alter table perfiles             enable row level security;
alter table categorias           enable row level security;
alter table productos            enable row level security;
alter table carrito_items        enable row level security;
alter table pedidos              enable row level security;
alter table pedido_items         enable row level security;
alter table facturas             enable row level security;
alter table vehiculos            enable row level security;
alter table tipos_servicio       enable row level security;
alter table solicitudes_servicio enable row level security;
alter table solicitud_tipos      enable row level security;
alter table fotos_servicio       enable row level security;
alter table presupuesto_items    enable row level security;
alter table config_taller        enable row level security;
alter table promociones          enable row level security;
alter table galeria              enable row level security;
alter table notificaciones       enable row level security;

-- ---- perfiles ----
create policy "perfiles: leer propio o staff" on perfiles
    for select using (id = auth.uid() or es_staff());
create policy "perfiles: editar propio o staff" on perfiles
    for update using (id = auth.uid() or es_staff());

-- ---- categorias / productos: todos leen, solo staff escribe ----
create policy "categorias: leer" on categorias
    for select using (auth.role() = 'authenticated');
create policy "categorias: staff escribe" on categorias
    for all using (es_staff()) with check (es_staff());

create policy "productos: leer" on productos
    for select using (auth.role() = 'authenticated');
create policy "productos: staff escribe" on productos
    for all using (es_staff()) with check (es_staff());

-- ---- carrito: cada quien maneja el suyo ----
create policy "carrito: dueno" on carrito_items
    for all using (usuario_id = auth.uid())
    with check (usuario_id = auth.uid());

-- ---- pedidos: cliente ve/crea los suyos, staff ve/edita todos ----
create policy "pedidos: leer propio o staff" on pedidos
    for select using (usuario_id = auth.uid() or es_staff());
create policy "pedidos: cliente crea propio" on pedidos
    for insert with check (usuario_id = auth.uid());
-- El staff puede editar cualquier pedido. El cliente dueno solo puede
-- cancelar el suyo (no marcarlo ENTREGADO ni tocar atendido_por) —
-- separado a proposito para que la UI de gestion (mecanico) no pueda
-- ser replicada por un cliente llamando el API directo.
create policy "pedidos: staff edita" on pedidos
    for update using (es_staff())
    with check (es_staff());
create policy "pedidos: cliente cancela propio" on pedidos
    for update using (usuario_id = auth.uid() and estado not in ('ENTREGADO', 'CANCELADO'))
    with check (usuario_id = auth.uid() and estado = 'CANCELADO');

-- ---- pedido_items: se accede segun el pedido padre ----
create policy "pedido_items: leer" on pedido_items
    for select using (
        exists (select 1 from pedidos p
                where p.id = pedido_id
                  and (p.usuario_id = auth.uid() or es_staff())));
create policy "pedido_items: crear" on pedido_items
    for insert with check (
        exists (select 1 from pedidos p
                where p.id = pedido_id and p.usuario_id = auth.uid()));
create policy "pedido_items: staff edita" on pedido_items
    for all using (es_staff()) with check (es_staff());

-- ---- facturas: cliente ve la suya, staff todas ----
create policy "facturas: leer" on facturas
    for select using (
        exists (select 1 from pedidos p
                where p.id = pedido_id
                  and (p.usuario_id = auth.uid() or es_staff())));
create policy "facturas: crear" on facturas
    for insert with check (
        exists (select 1 from pedidos p
                where p.id = pedido_id
                  and (p.usuario_id = auth.uid() or es_staff())));

-- ---- vehiculos: dueno o staff ----
create policy "vehiculos: dueno o staff" on vehiculos
    for select using (cliente_id = auth.uid() or es_staff());
create policy "vehiculos: cliente crea" on vehiculos
    for insert with check (cliente_id = auth.uid());
create policy "vehiculos: dueno o staff edita" on vehiculos
    for update using (cliente_id = auth.uid() or es_staff());
-- Solo permite borrar un vehiculo sin ninguna solicitud de servicio
-- asociada (rollback del check-in si falla el paso siguiente). Nunca
-- puede borrar un vehiculo con historial real, ni arrastrar en cascada
-- solicitudes existentes.
create policy "vehiculos: cliente elimina propio si esta huerfano" on vehiculos
    for delete using (
        cliente_id = auth.uid()
        and not exists (select 1 from solicitudes_servicio s where s.vehiculo_id = vehiculos.id)
    );

-- ---- tipos_servicio: todos leen, staff escribe ----
create policy "tipos_servicio: leer" on tipos_servicio
    for select using (auth.role() = 'authenticated');
create policy "tipos_servicio: staff escribe" on tipos_servicio
    for all using (es_staff()) with check (es_staff());

-- ---- solicitudes_servicio: cliente las suyas, staff todas ----
create policy "solicitudes: leer propio o staff" on solicitudes_servicio
    for select using (cliente_id = auth.uid() or es_staff());
create policy "solicitudes: cliente crea" on solicitudes_servicio
    for insert with check (cliente_id = auth.uid());
create policy "solicitudes: dueno o staff edita" on solicitudes_servicio
    for update using (cliente_id = auth.uid() or es_staff());

-- ---- solicitud_tipos: segun la solicitud padre ----
create policy "solicitud_tipos: acceso" on solicitud_tipos
    for all using (
        exists (select 1 from solicitudes_servicio s
                where s.id = solicitud_id
                  and (s.cliente_id = auth.uid() or es_staff())))
    with check (
        exists (select 1 from solicitudes_servicio s
                where s.id = solicitud_id
                  and (s.cliente_id = auth.uid() or es_staff())));

-- ---- fotos_servicio: segun la solicitud padre ----
create policy "fotos: acceso" on fotos_servicio
    for all using (
        exists (select 1 from solicitudes_servicio s
                where s.id = solicitud_id
                  and (s.cliente_id = auth.uid() or es_staff())))
    with check (
        exists (select 1 from solicitudes_servicio s
                where s.id = solicitud_id
                  and (s.cliente_id = auth.uid() or es_staff())));

-- ---- presupuesto_items: el mecanico escribe, el cliente dueno lee ----
create policy "presupuesto: leer" on presupuesto_items
    for select using (
        exists (select 1 from solicitudes_servicio s
                where s.id = solicitud_id
                  and (s.cliente_id = auth.uid() or es_staff())));

create policy "presupuesto: staff escribe" on presupuesto_items
    for all using (es_staff()) with check (es_staff());

-- ---- config_taller / promociones / galeria: todos leen, staff edita ----
create policy "config: leer" on config_taller
    for select using (true);
create policy "config: staff edita" on config_taller
    for all using (es_staff()) with check (es_staff());

create policy "promos: leer" on promociones
    for select using (true);
create policy "promos: staff edita" on promociones
    for all using (es_staff()) with check (es_staff());

create policy "galeria: leer" on galeria
    for select using (true);
create policy "galeria: staff edita" on galeria
    for all using (es_staff()) with check (es_staff());

-- ---- notificaciones: cada quien ve las suyas; staff puede crear ----
create policy "notif: leer propias" on notificaciones
    for select using (usuario_id = auth.uid());
create policy "notif: marcar leida" on notificaciones
    for update using (usuario_id = auth.uid());
create policy "notif: staff crea" on notificaciones
    for insert with check (es_staff());


-- =====================================================================
--  10. DATOS INICIALES (seed)
-- =====================================================================

-- Fila unica de configuracion del taller
insert into config_taller (id, nombre, mensaje_bienvenida, resumen_conocenos,
                           historia, mision, vision, horarios, telefono, whatsapp,
                           direccion, latitud, longitud)
values (1,
    'Taller Mecanico XYZ',
    'Bienvenido a Taller Mecanico XYZ',
    'Mas de 10 anios brindando servicios automotrices y venta de repuestos de calidad.',
    'Fundado en 2014, hemos crecido junto a nuestros clientes.',
    'Ofrecer servicios automotrices de calidad con atencion honesta y precios justos.',
    'Ser el taller de referencia en la region por su confianza y profesionalismo.',
    'Lunes a Viernes 8:00 AM - 6:00 PM, Sabados 8:00 AM - 1:00 PM',
    '+507 6000-0000',
    '+507 6000-0000',
    'Ciudad de Panama, Panama',
    8.9824, -79.5199);

-- Categorias
insert into categorias (nombre, orden) values
    ('Aceites', 1), ('Filtros', 2), ('Frenos', 3),
    ('Baterias', 4), ('Accesorios', 5);

-- Productos (25). El precio y el stock son valores de ejemplo, editables.
insert into productos (categoria_id, nombre, precio, stock, descripcion)
select c.id, p.nombre, p.precio, p.stock, p.descripcion
from (values
    ('Aceites',    'Castrol GTX',           35.00, 40, 'Aceite mineral 20W-50'),
    ('Aceites',    'Shell Helix',           38.00, 35, 'Aceite semisintetico'),
    ('Aceites',    'Mobil 1',               55.00, 25, 'Aceite full sintetico'),
    ('Aceites',    'Valvoline',             33.00, 30, 'Aceite mineral'),
    ('Aceites',    'Total Quartz',          36.00, 28, 'Aceite semisintetico'),
    ('Filtros',    'Filtro de aceite',       8.50, 60, 'Filtro de aceite universal'),
    ('Filtros',    'Filtro de aire',        12.00, 50, 'Filtro de aire de motor'),
    ('Filtros',    'Filtro de combustible', 15.00, 45, 'Filtro de combustible'),
    ('Filtros',    'Filtro de cabina',      18.00, 40, 'Filtro de aire acondicionado'),
    ('Filtros',    'Filtro universal',      10.00, 55, 'Filtro generico'),
    ('Frenos',     'Pastillas delanteras',  45.00, 30, 'Juego pastillas delanteras'),
    ('Frenos',     'Pastillas traseras',    42.00, 30, 'Juego pastillas traseras'),
    ('Frenos',     'Disco delantero',       65.00, 20, 'Disco de freno delantero'),
    ('Frenos',     'Disco trasero',         60.00, 18, 'Disco de freno trasero'),
    ('Frenos',     'Liquido de frenos',     12.00, 40, 'Liquido DOT 4'),
    ('Baterias',   'Bateria 500A',          85.00, 15, 'Bateria 12V 500A'),
    ('Baterias',   'Bateria 600A',          95.00, 12, 'Bateria 12V 600A'),
    ('Baterias',   'Bateria 700A',         110.00, 10, 'Bateria 12V 700A'),
    ('Baterias',   'Terminal positiva',      5.00, 50, 'Terminal de bateria (+)'),
    ('Baterias',   'Terminal negativa',      5.00, 50, 'Terminal de bateria (-)'),
    ('Accesorios', 'Limpiaparabrisas',      14.00, 40, 'Par de plumillas'),
    ('Accesorios', 'Fusibles',               3.50, 80, 'Set de fusibles surtidos'),
    ('Accesorios', 'Bombillos LED',         20.00, 35, 'Par de bombillos LED'),
    ('Accesorios', 'Refrigerante',          16.00, 45, 'Refrigerante de motor 1L'),
    ('Accesorios', 'Anticongelante',        18.00, 40, 'Anticongelante concentrado 1L')
) as p(categoria, nombre, precio, stock, descripcion)
join categorias c on c.nombre = p.categoria;

-- Marca algunos como destacados para el Inicio
update productos set destacado = true
where nombre in ('Castrol GTX', 'Bateria 600A', 'Pastillas delanteras');

-- Tipos de servicio (checklist)
insert into tipos_servicio (nombre) values
    ('Cambio de aceite'),
    ('Cambio de filtro'),
    ('Cambio de bateria'),
    ('Cambio de llantas'),
    ('Alineacion'),
    ('Balanceo'),
    ('Revision de frenos'),
    ('Diagnostico electronico'),
    ('Revision del motor'),
    ('Aire acondicionado'),
    ('Sistema electrico'),
    ('Mantenimiento preventivo');

-- Promociones de ejemplo (imagenes de relleno de picsum.photos, no son
-- fotos reales del taller; reemplazar por Supabase Storage cuando exista
-- panel de administracion de contenido).
insert into promociones (titulo, descripcion, imagen_url, precio, orden) values
    ('Cambio de aceite + filtro', 'Incluye revisión de niveles y presión de llantas', 'https://picsum.photos/seed/promo1/600/400', 45.00, 1),
    ('Diagnóstico electrónico gratis', 'Válido al contratar cualquier servicio mayor a $50', 'https://picsum.photos/seed/promo2/600/400', null, 2),
    ('Pastillas de freno + revisión', 'Delanteras o traseras, mano de obra incluida', 'https://picsum.photos/seed/promo3/600/400', 60.00, 3);

-- Galeria de ejemplo (mismo comentario que arriba sobre las imagenes)
insert into galeria (imagen_url, titulo, orden) values
    ('https://picsum.photos/seed/gal1/600/600', 'Área de trabajo', 1),
    ('https://picsum.photos/seed/gal2/600/600', 'Diagnóstico electrónico', 2),
    ('https://picsum.photos/seed/gal3/600/600', 'Fachada del taller', 3),
    ('https://picsum.photos/seed/gal4/600/600', 'Nuestro equipo', 4);


-- =====================================================================
--  11. STORAGE (fotos de check-in y de servicio)
--  Bucket publico: cualquiera con la URL puede ver la foto (simple,
--  suficiente para el alcance de este proyecto). Solo un usuario
--  autenticado puede subir, y unicamente dentro de su propia carpeta
--  (primer segmento de la ruta = su propio auth.uid()).
-- =====================================================================

insert into storage.buckets (id, name, public)
values ('fotos-servicio', 'fotos-servicio', true)
on conflict (id) do nothing;

create policy "fotos-servicio: subir en carpeta propia"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'fotos-servicio'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "fotos-servicio: leer publico"
on storage.objects for select
to public
using (bucket_id = 'fotos-servicio');

-- Bucket publico para fotos de producto (inventario). A diferencia del de
-- arriba, aqui solo el staff puede escribir (no hay carpeta por usuario,
-- cualquier mecanico/admin sube a cualquier ruta dentro del bucket).
insert into storage.buckets (id, name, public)
values ('productos', 'productos', true)
on conflict (id) do nothing;

create policy "productos-fotos: staff sube"
on storage.objects for insert
to authenticated
with check (bucket_id = 'productos' and public.es_staff());

create policy "productos-fotos: staff actualiza"
on storage.objects for update
to authenticated
using (bucket_id = 'productos' and public.es_staff())
with check (bucket_id = 'productos' and public.es_staff());

create policy "productos-fotos: staff elimina"
on storage.objects for delete
to authenticated
using (bucket_id = 'productos' and public.es_staff());

create policy "productos-fotos: leer publico"
on storage.objects for select
to public
using (bucket_id = 'productos');


-- =====================================================================
--  12. REALTIME
--  Habilita que Postgres transmita los cambios de esta tabla por
--  Supabase Realtime (el cliente escucha cuando el mecanico cambia el
--  estado de su solicitud, para mostrar una notificacion local).
-- =====================================================================

alter publication supabase_realtime add table solicitudes_servicio;

-- =====================================================================
--  FIN DEL ESQUEMA
-- =====================================================================
