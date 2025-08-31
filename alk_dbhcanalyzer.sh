#!/bin/bash

# Este script lê os dados coletados do STATSPACK e do OSWatcher e gera um relatório
# de verificação de saúde automático, preenchendo um template de relatório.

## # Configura o ambiente usando o SISDBA_HOME.
## export SISDBA_HOME=${HOME}/.alkdba
## source ${SISDBA_HOME}/lnx/bash_profile

# Define o diretório de dados e de saída do relatório.
## DATA_DIR="${SISDBA_HOME}/healthcheck/$(date +%Y-%m)"
## OUTPUT_FILE="${DATA_DIR}/relatorio_healthcheck_$(date +%Y%m).md"
TEMPLATE_FILE="${DATA_DIR}/templates/healthcheck_report_template.md"

# 1. Análise do STATSPACK.
# Extrai as informações-chave do relatório do STATSPACK.
SP_REPORT_FILE=$(find "${BASE_DIR}/statspack" -name "spreport_*.log" | head -n 1)

# Pega os Top Eventos de Espera.
TOP_EVENTS=$(grep -A 6 'Top 5 Timed Events' "$SP_REPORT_FILE" | grep -v 'Top 5' | tail -n 5)

# Pega o consumo de CPU.
DB_CPU_USAGE=$(grep 'DB CPU' "$SP_REPORT_FILE" | head -n 1 | awk '{print $3}')

# Pega as Top SQLs.
TOP_SQLS=$(grep -A 15 'SQL ordered by Elapsed time' "$SP_REPORT_FILE" | grep -A 10 'Rows' | tail -n 10)

# 2. Análise do Sistema Operacional.
# Extrai as informações-chave dos arquivos de sistema.
FREE_REPORT_FILE="${DATA_DIR}/system_info/free_h.txt"
DF_REPORT_FILE="${DATA_DIR}/system_info/df_h.txt"
SWAP_USED=$(grep 'Swap' "$FREE_REPORT_FILE" | awk '{print $3}')
DISK_FULL=$(grep '9[0-9]%' "$DF_REPORT_FILE")

# 3. Gerar o Relatório.
# Usa um template para preencher o relatório com as informações extraídas.
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Preenche os campos do template com os dados da análise.
sed -i "s|<data inicial>|$(date -d '2 days ago' +'%Y-%m-%d')|g" "$OUTPUT_FILE"
sed -i "s|<data final>|$(date +'%Y-%m-%d')|g" "$OUTPUT_FILE"

# Adiciona os dados do STATSPACK.
echo "### Dados Brutos do STATSPACK" >> "$OUTPUT_FILE"
echo "#### Top 5 Timed Events" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "$TOP_EVENTS" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "#### SQLs com Maior Consumo de Recursos" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "$TOP_SQLS" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"

# Adiciona os dados do OS.
echo "### Dados Brutos do Sistema Operacional" >> "$OUTPUT_FILE"
echo "#### Uso de Memória" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
grep 'Mem:' "$FREE_REPORT_FILE" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "#### Uso de Disco" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "Filesystem      Size  Used Avail Use% Mounted on" >> "$OUTPUT_FILE"
grep -v 'tmpfs' "$DF_REPORT_FILE" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"

# Lógica condicional para preencher o template de recomendações.
if (( $(echo "$DB_CPU_USAGE > 80" | bc -l) )); then
  # Preencher o template com recomendação de CPU.
  sed -i 's|<nome da consulta SQL>|...|' "$OUTPUT_FILE"
fi

if [[ -n "$SWAP_USED" && "$SWAP_USED" != "0B" ]]; then
  # Preencher o template com recomendação de memória.
  sed -i 's|<Recomendação de Memória>|O uso de swap indica que o sistema precisa de mais memória. Ajuste os parâmetros de SGA/PGA.|' "$OUTPUT_FILE"
fi

if [[ -n "$DISK_FULL" ]]; then
  # Preencher o template com recomendação de disco.
  sed -i 's|<Recomendação de Disco>|O disco está quase cheio, o que pode causar falhas no sistema. Liberar espaço ou adicionar mais armazenamento.|' "$OUTPUT_FILE"
fi

echo "Análise e geração de relatório concluídas. O arquivo está em: $OUTPUT_FILE"
