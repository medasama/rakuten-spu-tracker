-- ============================================================
-- 楽天SPU月次台帳（rakuten-spu-tracker）用 Supabase スキーマ
--
-- このツールは元々「window.storage.get/set/list」というシンプルな
-- キーバリュー形式でデータを保存する作りになっている。
-- そのため、このテーブルもキーバリュー方式にして、今アプリが保存している
-- 項目（月ごとの買い物記録・SPU設定・マラソン等イベント・39ショップイベント・
-- 買い物予定リスト・会員ランク・よく使う店舗名）をすべてそのまま保存できるようにしている。
--
-- 使い方：Supabaseダッシュボード → SQL Editor に貼り付けて実行してください。
-- 既に実行済みでも再実行して問題ないように書いてあります（べき等）。
-- ============================================================

-- 1. テーブル本体
create table if not exists public.rakuten_records (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now()
);

comment on table public.rakuten_records is
  '楽天SPU月次台帳のデータ（月次記録・設定など）をキーバリュー形式で保存するテーブル。
   key の例: spu-tracker:2026-08（月次記録一式のJSON）,
             spu-tracker-settings:rank（会員ランク）,
             spu-tracker-settings:shopHistory（よく使う店舗名のJSON配列）';

-- 2. updated_at を更新のたびに自動更新するトリガー
create or replace function public.set_rakuten_records_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_rakuten_records_updated_at on public.rakuten_records;
create trigger trg_rakuten_records_updated_at
before insert or update on public.rakuten_records
for each row execute function public.set_rakuten_records_updated_at();

-- 3. RLS（Row Level Security）を有効化
alter table public.rakuten_records enable row level security;

-- 4. anon（publishable key でのアクセス）に対して全操作を許可するポリシー
--    このツールはログイン機能を持たない個人用ツールのため、
--    publishable key を知っているクライアントからの読み書き削除をすべて許可する。
drop policy if exists "allow all for anon" on public.rakuten_records;
create policy "allow all for anon"
on public.rakuten_records
for all
to anon
using (true)
with check (true);

-- 5. Realtime同期を有効化（PC・スマホ間でリアルタイムに変更を反映するため）
alter table public.rakuten_records replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rakuten_records'
  ) then
    alter publication supabase_realtime add table public.rakuten_records;
  end if;
end $$;
