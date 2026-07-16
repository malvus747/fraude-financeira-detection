import pandas as pd
import psycopg2
import os
import time
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s  %(levelname)s  %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger(__name__)

CAMINHO_CSV = 'data/PS_20174392719_1491204439457_log.csv'
CONN_PARAMS = {
    "host": "localhost", "dbname": "fruad_detection",
    "user": "postgres",  "password": "kali"
}

def validar_csv():
    log.info("Validando estrutura do CSV (amostra de 10.000 linhas)...")
    t0 = time.time()
    df = pd.read_csv(CAMINHO_CSV, nrows=10000)

    colunas_esperadas = [
        'step','type','amount','nameOrig','oldbalanceOrg',
        'newbalanceOrig','nameDest','oldbalanceDest',
        'newbalanceDest','isFraud','isFlaggedFraud'
    ]
    assert list(df.columns) == colunas_esperadas, "Colunas inesperadas no CSV"
    assert df['amount'].ge(0).all(),               "Valores negativos em amount"
    assert df['isFraud'].isin([0,1]).all(),         "Valores inválidos em isFraud"

    log.info(f"Validação OK  ({time.time()-t0:.1f}s)")
    log.info(f"Tipos de transação: {df['type'].unique().tolist()}")
    log.info(f"% fraude (amostra): {df['isFraud'].mean()*100:.4f}%")

def criar_staging(conn):
    log.info("Criando tabela staging_transacao...")
    t0 = time.time()
    with conn.cursor() as cur:
        cur.execute("""
            DROP TABLE IF EXISTS staging_transacao CASCADE;
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
        """)
        conn.commit()
    log.info(f"staging_transacao criada  ({time.time()-t0:.1f}s)")

def carregar_via_copy(conn):
    log.info("Iniciando carga via COPY...")
    t0 = time.time()
    caminho = os.path.abspath(CAMINHO_CSV)
    with conn.cursor() as cur:
        with open(caminho, 'r') as f:
            next(f)  # pula header
            cur.copy_expert("""
                COPY staging_transacao (
                    step, type, amount, nameOrig,
                    oldbalanceOrg, newbalanceOrig,
                    nameDest, oldbalanceDest, newbalanceDest,
                    isFraud, isFlaggedFraud
                )
                FROM STDIN
                WITH (FORMAT CSV, HEADER FALSE, DELIMITER ',')
            """, f)
        conn.commit()

    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM staging_transacao")
        total = cur.fetchone()[0]

    duracao = time.time() - t0
    log.info(f"COPY concluído: {total:,} linhas em {duracao:.1f}s")

if __name__ == '__main__':
    log.info("=== INÍCIO DA IMPORTAÇÃO ===")
    inicio = time.time()
    try:
        validar_csv()
        conn = psycopg2.connect(**CONN_PARAMS)
        criar_staging(conn)
        carregar_via_copy(conn)
        conn.close()
        log.info(f"=== IMPORTAÇÃO CONCLUÍDA em {time.time()-inicio:.1f}s ===")
    except Exception as e:
        log.error(f"ERRO: {e}")
        raise