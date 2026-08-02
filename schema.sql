-- ============================================================
--  CS PLATFORM — Schema Completo para Supabase (Postgres)
--  Cole isso em: Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- PERFIS
-- ------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  cargo text default 'CS',
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- CLIENTES (Módulo: Carteira de Clientes)
-- ------------------------------------------------------------
create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  dominio text unique not null,
  razao_social text,
  nome_app text,
  responsavel text,
  cargo text,
  contato text,
  email text,
  parceiro text,
  vertical text default 'Fuel',
  prioridade text default 'Média',
  cidade text,
  uf text,
  engajamento text,
  satisfacao_percebida text,
  health_score text check (health_score in ('Saudável','Em Alerta','Em Risco','Retenção de Churn') or health_score is null),
  jornada text default 'Ongoing',
  mrr numeric default 0,
  tempo_contrato text,
  inadimplencia text default 'Não',
  ticket_url text,
  ultima_atividade text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- WORKFLOWS & FLUXOS DE TRABALHO (Módulo: Workflows)
-- ------------------------------------------------------------
create table if not exists workflows (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  titulo text not null,
  tipo text default 'Onboarding', -- 'Onboarding', 'Caso Crítico', 'Adoção / Expansão', 'Renovação', 'Rotina'
  etapa text not null default 'Parametrização & Criação do App', -- 'Acompanhamento Inicial', 'Parametrização & Criação do App', 'Validação & Testes', 'Virada de Chave / Go-Live', 'Acompanhamento Crítico', 'Concluído'
  prioridade text default 'Média', -- 'Baixa', 'Média', 'Alta', 'Urgente'
  responsavel text,
  descricao text,
  plano_de_acao text,
  proximo_contato date,
  ticket_url text,
  status text default 'Em Andamento' check (status in ('Em Andamento','Bloqueado','Concluído')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- ATIVIDADES & HISTÓRICO DE INTERAÇÕES
-- ------------------------------------------------------------
create table if not exists atividades (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  workflow_id uuid references workflows(id) on delete set null,
  tipo text not null, -- 'Follow-Up WhatsApp', 'Ligação / Contato', 'Reunião de Alinhamento', 'Treinamento', 'Virada de Chave', 'Visita Presencial', 'Check-In de Saúde', 'Outro'
  observacao text,
  data date default current_date,
  responsavel_id uuid references auth.users(id),
  created_at timestamptz default now()
);

-- Compatibilidade com tabelas legadas se existirem
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
  status text default 'Aberto',
  created_at timestamptz default now()
);

create table if not exists onboarding (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clientes(id) on delete cascade,
  etapa text,
  situacao text default 'Integração de Contrato',
  observacao text,
  ticket text,
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

drop trigger if exists trg_clientes_updated on clientes;
create trigger trg_clientes_updated before update on clientes
  for each row execute function set_updated_at();

drop trigger if exists trg_workflows_updated on workflows;
create trigger trg_workflows_updated before update on workflows
  for each row execute function set_updated_at();

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------
alter table profiles enable row level security;
alter table clientes enable row level security;
alter table workflows enable row level security;
alter table atividades enable row level security;
alter table casos_criticos enable row level security;
alter table onboarding enable row level security;

-- Políticas para usuários autenticados
create policy "profiles_all_auth" on profiles for all to authenticated using (true) with check (true);
create policy "clientes_all_auth" on clientes for all to authenticated using (true) with check (true);
create policy "workflows_all_auth" on workflows for all to authenticated using (true) with check (true);
create policy "atividades_all_auth" on atividades for all to authenticated using (true) with check (true);
create policy "casos_all_auth" on casos_criticos for all to authenticated using (true) with check (true);
create policy "onboarding_all_auth" on onboarding for all to authenticated using (true) with check (true);
