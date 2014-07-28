#---------------------------------------
#!/bin/bash
#---------------------------------------

# Arquivo de configuração
. /etc/zabbix/externalscripts/count.conf

# Desenvolvido por:
#	albertofreire@yahoo.com.br
#	08/07/2014 v1.0
#
#
# 

# Comandos do RouterOS:
p_pack=":put [/system package get [find name=ppp]];"
h_pack=":put [/system package get [find name=hotspot]];"
c_ppp="/ppp active print count-only"
c_hotspot="/ip hotspot active print count-only"

# Acessa o RouterOS via ssh e executa um comando; 
# 'query' deve ser informada entre aspas "" ao usar essa função.
consulta_ssh()
{
	local ip="$1"
	local query="$2"
	local user="${user_mk}"
	local port="${ssh_port}"
	local key="${chave_ssh}"
	local timeout_path="$(which timeout)"
	local ssh_path="$(which ssh)"

	exec_query="$(${timeout_path} -s9 10s\
		${ssh_path} -o StrictHostKeyChecking=no\
		-l ${user} -p${port} -i ${key} ${ip} ${query})"

	echo "$exec_query"
}
#----------------------------------------

# Verifica pacotes instalados no RouterOS.
auth_type()
{
	local pkg_p0="$(consulta_ssh $1 "$p_pack" | grep ppp)"
	local pkg_h0="$(consulta_ssh $1 "$h_pack" | grep hotspot)"
	local pkg_p="${#pkg_p0}"
	local pkg_h="${#pkg_h0}"

	if [ $pkg_p -ne 0 ]; then
		local ppp="1"
	else
		local ppp="0"
	fi

	if [ $pkg_h -ne 0 ]; then
		local hspot="2"
	else
		local hspot="0"
	fi

	# Se =0 é erro
	# Se =1 é ppp
	# Se =2 é hotspot
	# Se =3 são ambos
	echo "$(($ppp + $hspot))"
}

# Remove comentários e linhas em branco
addr="$(grep -v "^#" ${ips_mks} | sed '/^$/d')"

# Rotina principal para autenticação e consulta de clientes
for i in $addr;
do
	auth="$(auth_type $i)"
	case $auth in
		0)
			# Erro retorna zero, conferir se é um RouterOS ou se a key foi instalada
			echo "${auth}" > ${tmp_files}/${i}
		;;

		1)
			# Conta apenas pppoe
			echo "#PPPoE \n$(consulta_ssh ${i} "${c_ppp}")" > ${tmp_files}/${i}
		;;

		2)
			# Conta apenas hotspot
			echo "#Hotspot \n$(consulta_ssh ${i} "${c_hotspot}")" > ${tmp_files}/${i}
		;;

		3)
			# Conta hotspot e pppoe (ambos)
			echo "#PPPoE \n$(consulta_ssh ${i} "${c_ppp}")\
				\n#Hotspot \n$(consulta_ssh ${i} "${c_hotspot}")" > ${tmp_files}/${i}
		;;
	esac
done

exit 0