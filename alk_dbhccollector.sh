#!/bin/bash

# Configura o ambiente usando o SISDBA_HOME.
# Define o caminho do SISDBA_HOME e carrega as variáveis de ambiente necessárias.
# Isso garante que o script funcione em qualquer servidor com a estrutura padronizada.
export SISDBA_HOME=${HOME}/.alkdba
source ${SISDBA_HOME}/lnx/bash_profile

# Define o diretório base para armazenar os relatórios usando a variável de ambiente.
# A gente define o nome do diretório como o ano-mês, por exemplo, para manter a organização.
BASE_DIR="${SISDBA_HOME}/healthcheck/$(date +%Y-%m)"

# Cria os diretórios necessários.
# Os diretórios são criados se não existirem, garantindo que o script não falhe.
mkdir -p $BASE_DIR/{statspack,oswatcher,system_info}

# 1. Automatiza a coleta e geração do relatório do STATSPACK.
# Esta parte do script automatiza a interação com o spreport.sql, que é interativo.
echo "Coletando dados do STATSPACK em \"${BASE_DIR}\"..."

# Coleta os snap_id inicial e final para o período das últimas 48 horas.
# Usamos o sqlplus para consultar a tabela STATS$SNAPSHOT e encontrar os IDs de interesse.
SNAP_IDS=$(${ORACLE_HOME}/bin/sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF VERIFY OFF
SELECT snap_id FROM STATS\$SNAPSHOT
WHERE snap_time >= SYSDATE - 2
ORDER BY snap_id ASC;
EXIT;
EOF
)

# Separa os IDs em variáveis.
SNAP_ID_BEGIN=$(echo "$SNAP_IDS" | head -n 1 | xargs)
SNAP_ID_END=$(echo "$SNAP_IDS" | tail -n 1 | xargs)

# Nome do arquivo de saída.
OUTPUT_FILE="${BASE_DIR}/statspack/spreport_$(date +%Y%m%d%H%M)_${SNAP_ID_BEGIN}_${SNAP_ID_END}.log"

# Roda o spreport de forma não interativa.
# Usamos um 'here document' (<< EOF...EOF) para passar as respostas ao script sem interação manual.
${ORACLE_HOME}/bin/sqlplus / as sysdba << EOF > "${OUTPUT_FILE}"
@${ORACLE_HOME}/rdbms/admin/spreport.sql
${SNAP_ID_BEGIN}
${SNAP_ID_END}
${OUTPUT_FILE}
EOF

# 2. Coleta os dados do OSWatcher.
# O OSWatcher já coleta os dados em um diretório, a gente só precisa comprimir e mover para o nosso diretório de relatório.
echo "Coletando dados do OSWatcher..."
# Define o diretório de dados do OSWatcher a partir da saída do processo.
# Este caminho é específico para o ambiente do cliente, conforme a saída do 'ps'.
OW_DATA_DIR="/opt/oracle.ahf/data/repository/suptools/srvora19prd/oswbb/oracle/archive" # é possível tornar essa descoberta e declaração dinâmica?
# Comprime o conteúdo do diretório de dados do OSWatcher e o salva no nosso diretório de healthcheck.
tar -czvf "${BASE_DIR}/oswatcher/oswatcher_data_$(date +%Y%m%d%H%M).tar.gz" -C "${OW_DATA_DIR}" .

# 3. Coleta informações adicionais do sistema operacional.
# Esses comandos salvam a saída em arquivos de texto para análise posterior.
echo "Coletando informações adicionais do sistema operacional..."
df -h > "${BASE_DIR}/system_info/df_h.txt"
iostat -x > "${BASE_DIR}/system_info/iostat_x.txt"
vmstat > "${BASE_DIR}/system_info/vmstat.txt"
free -h > "${BASE_DIR}/system_info/free_h.txt"
uname -a > "${BASE_DIR}/system_info/uname_a.txt"
cat /etc/os-release > "${BASE_DIR}/system_info/os_release.txt"

echo "Coleta de dados concluída. Os arquivos estão em: ${BASE_DIR}"
