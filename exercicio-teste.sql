--Transformar a tabela de vendas particionada por ano. Lembre-se de
--verificar todos os anos possíveis para criar as partições de forma
--correta;


----------------------------------------------------------------------------------------------
--Crie um PIVOT TABLE para saber o total vendido por grupo de
--produto por mês referente a um determinado ano;


select * from crosstab(
$$
	select  foo.mes, pg.name,
		coalesce(sum((si.quantity * p.sale_price)) filter (where to_char(s.date, 'mm/yyyy') = foo.mes), 0) as total
from sale s 
	cross join (select format('%s/%s', lpad(generate_series(1, 12)::varchar, 2, '0'),2020) as mes) as foo
	left join sale_item si on s.id = si.id_sale
	left join product p on si.id_product = p.id
	left join product_group pg on pg.id = p.id_product_group
where date_part('year', s.date) = 2020
group by 1,2
order by 1,2;
$$,
	$$
		select pg.name from product_group pg order by pg.id
	$$
) as ( mes varchar, limpeza varchar, informática varchar, alimentício varchar, eletrônicos varchar);	


----------------------------------------------------------------------------------------------------
--• Crie um PIVOT TABLE para saber o total de clientes por bairro e zona;
select d.name, z.name, count(*) from  customer c
	inner join district d on d.id = c.id_district
	inner join zone z on z.id = d.id_zone
	group by 1,2
	order by 2
;

select * from crosstab(
$$
	select d.name, z.name, count(*) from  customer c
	inner join district d on d.id = c.id_district
	inner join zone z on z.id = d.id_zone
	group by 1,2
	order by 2
$$,
	$$
		select z.name from zone z order by z.id
	$$
) as (bairro varchar, norte integer, sul integer, leste integer, oeste integer);


------------------------------------------------------------------------------------

--Crie uma coluna para saber o preço unitário do item de venda, crie
--um script para atualizar os dados já existentes e logo em seguida uma
--trigger para preencher o campo;


select * from sale_item si where si.id_sale = 1;

alter table sale_item add column unit_price numeric(10,2)

alter table sale_item drop column unit_price

update sale_item set unit_price = 0.00;

update sale_item si set 
unit_price =  (select pr.sale_price   from  product pr)
where si.id_product (select pr.id  from  product pr) ; 
										 
select pr.sale_price   from  product pr
	right join product pr on si.id_product = pr.id
where si.id_product = pr.id order by pr.id ;


commit;

select * from sale_item

select * from usando_tipos();


do
$$
declare
	consulta record;
begin
	for consulta in select sale_price from product loop
		raise notice 'sale_price: %', consulta.sale_price;
	end loop;	
end
$$

create or replace function fn_atualiza_unit_price() returns table(id_product integer, valor_sale_price numeric) as
$$
declare
	consulta record;
begin
	for consulta in select id, sale_price from product loop
		id_product := consulta.id;
		valor_sale_price := consulta.sale_price;
		return next;
	end loop;
	return;
end;
$$
language plpgsql;


create or replace function fn_atualiza_unit_price_2() returns table(id_product integer, valor_sale_price numeric) as
$$
declare
	consulta record;
	consulta2 record;
begin
	for consulta in select id, sale_price from product loop
	for consulta2 in select id, unit_price from sale_item loop
		for i in 
		id_product := consulta.id;
		valor_sale_price := consulta.sale_price;
		return next;
	end loop;
	return ;
end;
$$
language plpgsql;



select * from fn_atualiza_unit_price();

select pr.id, pr.sale_price from product pr order by pr.id
-------------------------------------------------------------------------------------------------
--Crie um campo para saber o total da venda, crie um script para
--atualizar os dados já existentes, em seguida uma trigger para
--preencher o campo de forma automática;

select * from sale s;

alter table sale add column total_sale numeric(10,2) 


-------------------------------------------------------------------------------------------------
--• Baseado no banco de dados de crime vamos fazer algumas questões.
--• 1 - Criar o banco de dados;
--• 2 - Criar o DDL para estrutura das tabelas;
--• 3 - Criar um script para criar armas de forma automática, seguindo os
--seguintes critérios: O número de série da arma deve ser gerado por o UUID,
--os tipos de armas são, 0 - Arma de fogo, 1 - Arma branca, 2 - Outros.



create database sistema_crime;

CREATE TABLE arma (
  id SERIAL,
  numero_serie VARCHAR(104),
  descricao VARCHAR(255) NOT NULL,
  tipo VARCHAR(1) NOT NULL,
  CONSTRAINT PK_arma PRIMARY KEY (id)
);

CREATE TABLE tipo_crime (
  id SERIAL,
  nome VARCHAR(104) NOT NULL,
  tempo_minimo_prisao SMALLINT,
  tempo_maximo_prisao SMALLINT,
  tempo_prescricao SMALLINT,
  CONSTRAINT PK_tipo_crime PRIMARY KEY (id)
);

CREATE TABLE crime (
  id SERIAL,
  data TIMESTAMP NOT NULL,
  local VARCHAR(255) NOT NULL,
  observacao TEXT,
  id_tipo_crime INTEGER[?DIMENSION?] NOT NULL,
  CONSTRAINT PK_crime PRIMARY KEY (id)
);

CREATE TABLE crime_arma (
  id SERIAL,
  id_arma INTEGER[?DIMENSION?] NOT NULL,
  id_crime INTEGER[?DIMENSION?] NOT NULL,
  CONSTRAINT PK_crime_arma PRIMARY KEY (id)
);

CREATE TABLE pessoa (
  id SERIAL,
  nome VARCHAR(104) NOT NULL,
  cpf VARCHAR(14) NOT NULL,
  telefone VARCHAR(11) NOT NULL,
  data_nascimento DATE NOT NULL,
  ativo BOOLEAN NOT NULL,
  criado_em TIMESTAMP NOT NULL,
  modificado_em TIMESTAMP NOT NULL,
  endereco VARCHAR(255) NOT NULL,
  CONSTRAINT PK_pessoa PRIMARY KEY (id)
);

CREATE TABLE crime_pessoa (
  id SERIAL,
  id_pessoa INTEGER NOT NULL,
  id_crime INTEGER NOT NULL,
  NEW_COLUMN VARCHAR(1) NOT NULL,
  CONSTRAINT PK_crime_pessoa PRIMARY KEY (id)
);


CREATE UNIQUE INDEX ak_tipo_crime_nome ON tipo_crime (nome);

CREATE UNIQUE INDEX ak_crime_arma ON crime_arma (id_arma);

CREATE UNIQUE INDEX ak_pessoa_crime ON crime_pessoa (id_crime);


ALTER TABLE crime
  ADD CONSTRAINT FK_crime_tipo_crime
  FOREIGN KEY (id_tipo_crime) REFERENCES tipo_crime (id);

ALTER TABLE crime_arma
  ADD CONSTRAINT FK_crime_arma_arma
  FOREIGN KEY (id_arma) REFERENCES arma (id);

ALTER TABLE crime_arma
  ADD CONSTRAINT FK_crime_arma_crime
  FOREIGN KEY (id_crime) REFERENCES crime (id);

ALTER TABLE crime_pessoa
  ADD CONSTRAINT FK_crime_pessoa_pessoa
  FOREIGN KEY (id_pessoa) REFERENCES pessoa (id);

ALTER TABLE crime_pessoa
  ADD CONSTRAINT FK_crime_pessoa_crime
  FOREIGN KEY (id_crime) REFERENCES crime (id);


ALTER TABLE arma add column nb_tipo integer not null;

--0 - Arma de fogo, 1 - Arma branca, 2 - Outros.
ALTER TABLE arma add constraint check_tipo_arma check (nb_tipo in ('0','1','2'));


---------------------------------------------------------------------------------------------
--• Faça um script para migrar todos os clientes e funcionários da base de
--vendas como pessoas na base de dados de crimes. Os campos que
--por ventura não existirem, coloque-os como nulo ou gere de forma
--aleatória.

