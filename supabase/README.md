# Supabase: S3 Bank

## Aplicar o schema
1. Painel do Supabase > SQL Editor > cole `migrations/0001_schema.sql` e execute.
2. Em Authentication > Providers, mantenha Email habilitado.

## Regras
- O saldo é sempre `sum(ledger_entries.amount_cents)`; não há coluna de saldo editável.
- Escritas só por funções `security definer` (`pix_transfer`, `simulate_deposit`).
- A anon key pode ficar no app. Nunca use a service_role key no cliente.

## Testes contra o Supabase real
1. Authentication > Providers > Email: desligue "Confirm email" (só para o projeto de teste).
2. Rode:

```
flutter test test/integration --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_ANON_KEY
```

Os testes criam usuários de teste a cada execução. Eles são pulados se as variáveis não forem passadas, então o CI não depende do banco.
