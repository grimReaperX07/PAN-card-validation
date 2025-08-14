--1.Data Cleaning Steps:
--Identify missing data
select * from pan_number_dataset
where pan_number is null

--Check for duplictaes
select pan_number,count(*) 
from pan_number_dataset
group by pan_number
having count(*)>1 

--Check leading/trailing spaces
select * 
from pan_number_dataset
where pan_number != trim(pan_number)

--Corect casing
select * 
from pan_number_dataset
where pan_number != upper(pan_number)

--Cleaned PAN numbers
select distinct(upper(trim(pan_number))) as pan_number
from pan_number_dataset
where pan_number is not null and trim(pan_number) != ''

--2.Data Validation: correct PAN format
--User Defined Func to check if adj chars are same

CREATE OR REPLACE FUNCTION fn_check_adj_char(p_str text)
RETURNS boolean 
AS $$
BEGIN
	FOR i in 1 .. (length(p_str)-1)
	LOOP 
		IF substring(p_str,i,1) = substring(p_str,i+1,1)
		THEN 
			RETURN TRUE; -- chars are adj
		END IF;	
	END LOOP;
	RETURN FALSE;
END; $$
LANGUAGE PLPGSQL;

--func check
select fn_check_adj_char('ZCOVO')

--User Defined Func to check if sequential chars are used

CREATE OR REPLACE FUNCTION fn_check_sequ_char(p_str text)
RETURNS boolean 
AS $$
BEGIN
	FOR i in 1 .. (length(p_str)-1)
	LOOP 
		IF ascii(substring(p_str,i+1,1)) - ascii(substring(p_str,i,1)) != 1
		THEN 
			RETURN FALSE; -- chars are not sequential
		END IF;	
	END LOOP;
	RETURN TRUE; -- chars are sequential
END; $$
LANGUAGE PLPGSQL;

--func check
select fn_check_sequ_char('ABABA')

--REGEX to check valid PAN pattern
select * 
from pan_number_dataset
where pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'

--Valid and Invalid PAN categorization

create or replace view vw_valid_invalid_pans as
with cte_cleaned_pan as
(
	select distinct(upper(trim(pan_number))) as pan_number
	from pan_number_dataset
	where pan_number is not null and trim(pan_number) != ''
),
cte_valid_pan as
(
	select * 
	from cte_cleaned_pan
	where fn_check_adj_char(pan_number) = false
	and fn_check_sequ_char(substring(pan_number,1,5)) = false
	and fn_check_sequ_char(substring(pan_number,6,4)) = false
	and pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
select clp.pan_number
,case 
	when vlp.pan_number is not null then 'Valid PAN' 
	else 'Invalid PAN'
	end as Status
from cte_cleaned_pan clp
left join cte_valid_pan vlp 
on clp.pan_number = vlp.pan_number

--View Check
select * from vw_valid_invalid_pans

--Summary Report
with cte as
(
	select 
	(select count(*) from pan_number_dataset) as total_records
	,count(*) filter (where status = 'Valid PAN') as total_valid_pans
	,count(*) filter (where status = 'Invalid PAN') as total_invalid_pans
from vw_valid_invalid_pans
)
select 
	total_records,
	total_valid_pans,
	total_invalid_pans, 
	total_records-(total_valid_pans+total_invalid_pans) as total_missing_pans
from cte
