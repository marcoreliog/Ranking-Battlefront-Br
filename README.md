# Battlefront BR

Aplicação full-stack para rankings da comunidade brasileira de jogadores de Star Wars Battlefront II no Xbox. Usa Next.js App Router, Supabase Auth/PostgreSQL, RLS e Vercel.

## Sobre o projeto

Este projeto foi criado por **Aurelliuz**, também conhecido como **Maestro** na comunidade e no Xbox.

O objetivo é servir como uma experiência de aprendizado no desenvolvimento de uma aplicação full-stack e, ao mesmo tempo, proporcionar diversão entre amigos e colegas da comunidade de Star Wars Battlefront II.

## Pré-requisitos

- Node.js 22+ e npm 10+
- Conta e projeto no [Supabase](https://supabase.com)
- Opcional para migrations: [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
- Conta na Vercel

## Instalação local

```bash
git clone <seu-repositorio>
cd Battlefront-br
npm install
cp .env.example .env.local
```

Crie um projeto no Supabase. Em **Project Settings → API**, copie a URL e a chave **Publishable** (nunca a `service_role`) para `.env.local`:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
NEXT_PUBLIC_SITE_URL=http://localhost:3000
MIN_RATINGS_PER_MODE=3
```

`MIN_RATINGS_PER_MODE` é lida pelo app ao executar os RPCs de ranking. A `service_role` não é necessária nesta versão e não deve ser configurada.

## Banco de dados, migrations e seed

Com um projeto Supabase vinculado:

```bash
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase db push
psql "$SUPABASE_DB_URL" -f supabase/seed.sql
```

Alternativamente, no **SQL Editor** execute primeiro `supabase/migrations/20260920120000_initial_schema.sql` e depois `supabase/seed.sql`. O seed é idempotente e contém os 22 personagens solicitados.

Para desenvolvimento local:

```bash
npx supabase start
npx supabase db reset
```

## Primeiro administrador

1. Crie uma conta em `/cadastro` usando usuário e senha.
2. No SQL Editor, execute:

```sql
update public.profiles
set role = 'admin'
where gamertag = 'SEU_GAMERTAG';
```

Não existe fluxo de “primeiro visitante vira admin”. O trigger impede alteração de papel pela API; o SQL Editor é a via de bootstrap.

## Rodar e validar

```bash
npm run dev
npm run test
npm run lint
npm run typecheck
npm run build -- --webpack
```

O Webpack é uma alternativa quando o Turbopack está bloqueado por sandbox. Em uma máquina comum, `npm run build` basta.

Os testes Vitest cobrem fórmula geral, notas de meio ponto, CSV, constraints/UPSERT e Top 4 no contrato SQL. Para E2E, inicie o app com um Supabase de teste configurado:

```bash
npm run dev
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 npm run test:e2e
```

Playwright executa desktop e viewport mobile. Para avaliação/autenticação isoladas, use um projeto Supabase separado e usuários de teste.

## Publicar na Vercel

1. Suba o repositório e importe-o na Vercel.
2. Em **Settings → Environment Variables**, crie as quatro variáveis de `.env.example` para Production, Preview e Development. Use a URL final em `NEXT_PUBLIC_SITE_URL` na produção.
3. Faça o deploy. Não cadastre `service_role` na Vercel para este app.
4. No Supabase, em **Authentication → URL Configuration**, configure:

```text
Site URL: https://seu-dominio.com.br
Redirect URLs:
https://seu-dominio.com.br/auth/callback
https://*.vercel.app/auth/callback
http://localhost:3000/auth/callback
```

5. Em **Authentication → Providers → Email**, deixe o provedor de senha habilitado, mas **desative Confirm email**. A interface não coleta e-mails: ela cria um identificador técnico interno para que o Supabase Auth possa manter senhas com segurança. Discord OAuth pode ser incluído depois em Providers.
6. Em **Vercel → Settings → Domains**, adicione o domínio, configure o DNS e atualize Site URL/Redirect URLs no Supabase.

## Segurança e manutenção

- Todas as tabelas expostas têm RLS. Views e funções públicas removem UUIDs, e-mails e autores de avaliações das respostas públicas.
- `is_admin()` consulta somente `profiles.role`; autorização não usa `raw_user_meta_data`.
- Notas passam por Zod, Server Action e checks SQL; RPCs fazem UPSERT atômico e rate limit de dois segundos por usuário.
- O painel desativa jogadores em vez de excluí-los. Importação é validada antes da inserção e é atômica quando não há erros por linha.
- Cabeçalhos de segurança ficam em `next.config.ts`; `@supabase/ssr` com `proxy.ts` guarda e renova cookies de sessão via `getClaims()`.
- O login é por usuário e senha. `username` é único, não é público e não pode ser alterado. Sem e-mail ou telefone verificável, a recuperação automática de senha não é possível; `/esqueci-senha` orienta a recuperação manual pela administração.

Faça backups periódicos em **Database → Backups** do Supabase e antes de migrations importantes. Monitore Auth, logs de banco e Vercel; mantenha dependências atualizadas e publique migrations com `supabase db push`.

## Estrutura

```text
app/                    Rotas App Router, Server Actions e metadados
components/             Interface e formulários, incluindo componentes shadcn/ui
lib/supabase/           Clientes SSR/browser
lib/validators/         Schemas Zod
lib/rankings/           Fórmula isolada e testável
supabase/migrations/    Schema, RLS, RPCs e rankings SQL
supabase/seed.sql       Seed idempotente dos 22 heróis
tests/ e2e/             Vitest e Playwright
```
