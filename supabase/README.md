# Supabase: S3 Bank

## Aplicar o schema
1. Painel do Supabase > SQL Editor > cole `migrations/0001_schema.sql` e execute.
2. Em Authentication > Providers, mantenha Email habilitado.

## Regras
- O saldo é sempre `sum(ledger_entries.amount_cents)`; não há coluna de saldo editável.
- Escritas só por funções `security definer` (`pix_transfer`, `simulate_deposit`).
- A anon key pode ficar no app. Nunca use a service_role key no cliente.
