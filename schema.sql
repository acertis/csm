-- ============================================================
--  CS PLATFORM v2 — Schema para Supabase (Postgres)
--  Cole isso em: Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- PERFIS (dados extras do usuário, ligado ao auth.users nativo do Supabase)
-- ------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  cargo text default 'CS',
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- CLIENTES (equivalente à aba "Informações" + "Segmentação da Carteira")
-- ------------------------------------------------------------
create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  dominio text unique not null,
  razao_social text,
  nome_app text,
  responsavel text,
  vertical text,
  prioridade text,
  cidade text,
  uf text,
  engajamento text,
  satisfacao_percebida text,
  health_score text check (health_score in ('Saudável','Em Alerta','Em Risco','Retenção de Churn') or health_score is null),
  jornada text,
  mrr numeric default 0,
  tempo_contrato text,
  inadimplencia text default 'Não',
  ultima_atividade text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- CASOS CRÍTICOS (Gestão de Risco)
-- ------------------------------------------------------------
create table if not exists casos_criticos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  parceiro text,
  tipo text,
  situacao text,
  plano_de_acao text,
  ultimos_contatos text,
  proximo_contato date,
  ticket text,
  responsavel text,
  status text default 'Aberto' check (status in ('Aberto','Resolvido')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- ONBOARDING (Kanban)
-- ------------------------------------------------------------
create table if not exists onboarding (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  etapa text,
  situacao text default 'Integração de Contrato',
  observacao text,
  ticket text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- ATIVIDADES (log de contatos/reuniões — alimenta os indicadores do Dashboard)
-- ------------------------------------------------------------
create table if not exists atividades (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  tipo text not null, -- ex: 'Aguardando Contato','Follow-Up','Reunião Agendada','Reunião Realizada','Treinamento','Visita Presencial'...
  observacao text,
  data date default current_date,
  responsavel_id uuid references auth.users(id),
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- TRIGGER: mantém updated_at sempre atualizado
-- ------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_clientes_updated before update on clientes
  for each row execute function set_updated_at();
create trigger trg_casos_updated before update on casos_criticos
  for each row execute function set_updated_at();
create trigger trg_onboarding_updated before update on onboarding
  for each row execute function set_updated_at();

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY — por enquanto: qualquer usuário logado
-- pode ler e escrever (login simples, sem níveis de permissão ainda)
-- ------------------------------------------------------------
alter table profiles enable row level security;
alter table clientes enable row level security;
alter table casos_criticos enable row level security;
alter table onboarding enable row level security;
alter table atividades enable row level security;

create policy "logados podem ler perfis" on profiles for select using (auth.role() = 'authenticated');
create policy "usuário edita o próprio perfil" on profiles for update using (auth.uid() = id);
create policy "novo usuário cria o próprio perfil" on profiles for insert with check (auth.uid() = id);

create policy "logados podem ler clientes" on clientes for select using (auth.role() = 'authenticated');
create policy "logados podem inserir clientes" on clientes for insert with check (auth.role() = 'authenticated');
create policy "logados podem editar clientes" on clientes for update using (auth.role() = 'authenticated');
create policy "logados podem apagar clientes" on clientes for delete using (auth.role() = 'authenticated');

create policy "logados podem ler casos" on casos_criticos for select using (auth.role() = 'authenticated');
create policy "logados podem inserir casos" on casos_criticos for insert with check (auth.role() = 'authenticated');
create policy "logados podem editar casos" on casos_criticos for update using (auth.role() = 'authenticated');
create policy "logados podem apagar casos" on casos_criticos for delete using (auth.role() = 'authenticated');

create policy "logados podem ler onboarding" on onboarding for select using (auth.role() = 'authenticated');
create policy "logados podem inserir onboarding" on onboarding for insert with check (auth.role() = 'authenticated');
create policy "logados podem editar onboarding" on onboarding for update using (auth.role() = 'authenticated');
create policy "logados podem apagar onboarding" on onboarding for delete using (auth.role() = 'authenticated');

create policy "logados podem ler atividades" on atividades for select using (auth.role() = 'authenticated');
create policy "logados podem inserir atividades" on atividades for insert with check (auth.role() = 'authenticated');

-- ------------------------------------------------------------
-- Cria o perfil automaticamente quando um usuário se registra
-- ------------------------------------------------------------
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, nome) values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
