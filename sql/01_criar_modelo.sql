-- ============================================================
-- 01_criar_modelo.sql
-- Script de fundação: Apaga tabelas antigas e cria a nova estrutura
-- ============================================================

-- Primeiro, limpamos tudo para garantir que o script funcione do zero
DROP TABLE IF EXISTS alerta_fraude CASCADE;
DROP TABLE IF EXISTS transacao CASCADE;
DROP TABLE IF EXISTS conta CASCADE;
DROP TABLE IF EXISTS tipo_transacao CASCADE;
DROP TABLE IF EXISTS dim_tempo CASCADE;
DROP TABLE IF EXISTS staging_transacao CASCADE;

-- 1. STAGING
CREATE TABLE staging_transacao (
    id_staging     BIGSERIAL PRIMARY KEY,
    step           INTEGER,
    type           VARCHAR(20),
    amount         NUMERIC(18,2),
    nameOrig       VARCHAR(20),
    oldbalanceOrg  NUMERIC(18,2),
    newbalanceOrig NUMERIC(18,2),
    nameDest       VARCHAR(20),
    oldbalanceDest NUMERIC(18,2),
    newbalanceDest NUMERIC(18,2),
    isFraud        SMALLINT,
    isFlaggedFraud SMALLINT
);

-- 2. DIMENSÃO: Tempo
CREATE TABLE dim_tempo (
    id_tempo       INTEGER PRIMARY KEY,
    hora           INTEGER,
    dia            INTEGER,
    semana         INTEGER,
    periodo        VARCHAR(15),
    turno          VARCHAR(15),
    fim_de_semana  BOOLEAN
);

-- 3. DIMENSÃO: Tipo
CREATE TABLE tipo_transacao (
    id_tipo   SERIAL PRIMARY KEY,
    descricao VARCHAR(20) NOT NULL UNIQUE
);

-- 4. DIMENSÃO: Conta
CREATE TABLE conta (
    id_conta   SERIAL PRIMARY KEY,
    nome_conta VARCHAR(20) NOT NULL UNIQUE
);

-- 5. FATO: Transações
CREATE TABLE transacao (
    id_transacao         SERIAL PRIMARY KEY,
    id_origem_csv        BIGINT,
    id_tempo             INTEGER      REFERENCES dim_tempo(id_tempo),
    id_tipo              INTEGER      REFERENCES tipo_transacao(id_tipo),
    amount               NUMERIC(18,2) NOT NULL,
    id_conta_origem      INTEGER      REFERENCES conta(id_conta),
    saldo_antes_origem   NUMERIC(18,2),
    saldo_depois_origem  NUMERIC(18,2),
    id_conta_destino     INTEGER      REFERENCES conta(id_conta),
    saldo_antes_destino  NUMERIC(18,2),
    saldo_depois_destino NUMERIC(18,2),
    is_fraude            BOOLEAN NOT NULL,
    is_flagged_fraude    BOOLEAN NOT NULL
);

-- 6. ALERTAS
CREATE TABLE alerta_fraude (
    id_alerta       SERIAL PRIMARY KEY,
    id_transacao    INTEGER REFERENCES transacao(id_transacao),
    tipo_alerta     VARCHAR(60)   NOT NULL,
    severidade      VARCHAR(10)   NOT NULL,
    valor_envolvido NUMERIC(18,2),
    descricao       TEXT,
    criado_em       TIMESTAMP DEFAULT NOW()
);

-- 7. ÍNDICES (Performance)
CREATE INDEX idx_tx_fraude   ON transacao(is_fraude);
CREATE INDEX idx_tx_tipo     ON transacao(id_tipo);
CREATE INDEX idx_tx_origem   ON transacao(id_conta_origem);
CREATE INDEX idx_tx_destino  ON transacao(id_conta_destino);
CREATE INDEX idx_tx_amount   ON transacao(amount);
CREATE INDEX idx_tx_tempo    ON transacao(id_tempo);
CREATE INDEX idx_st_orig     ON staging_transacao(nameOrig);
CREATE INDEX idx_st_dest     ON staging_transacao(nameDest);