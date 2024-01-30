--A
--1
select count(distinct(node_id)) as no_of_unique_nodes 
from customer_nodes ;

--2
select r.region_name, count(distinct(cn.node_id)) as no_of_unique_nodes from customer_nodes cn
natural join regions r
group by r.region_name;

--3
select r.region_name, count(distinct(cn.customer_id)) as no_of_customers from customer_nodes cn
natural join regions r
group by r.region_name;

--4
select round(avg(end_date - start_date)) as avg_rellocation_days from customer_nodes
where end_date != '9999-12-31';

--5
WITH dayscte AS (
    SELECT 
        cn.region_id,
        r.region_name,
        end_date - start_date AS reallocation_days
	from customer_nodes cn
    natural join regions r
    WHERE end_date != '9999-12-31')
	
	
SELECT region_id, region_name,
   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reallocation_days) as Median,
   PERCENTILE_DISC(0.8) WITHIN GROUP (ORDER BY reallocation_days) as percentile_80,
   PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY reallocation_days) as percentile_95
   FROM dayscte
   GROUP BY region_id, region_name;

--B
--1
select txn_type, count(txn_type) as count_of_txn, to_char(sum(txn_amount), 'FM$ 999,999,999') as total_amount 
from customer_transactions
group by txn_type;

--2
with tab1 as (select count(txn_type) as count_txn, avg(txn_amount) as total_amount 
from customer_transactions
group by customer_id, txn_type
having txn_type = 'deposit')

select round(avg(count_txn)) as avg_count_txn, to_char(round(avg(total_amount), 2), 'FM$ 999,999,999') as avg_total_amount 
from tab1;

--3
with tab2 as (SELECT customer_id, EXTRACT(MONTH FROM txn_date) as month_no, 
			  count(case when txn_type = 'deposit' then 1 end) as deposit,
			  count(case when txn_type = 'purchase' then 1 end) as purchase,
			  count(case when txn_type = 'withdrawal' then 1 end) as withdrawal
			  from customer_transactions
			 group by customer_id, month_no
			  order by customer_id
			 ) 

select month_no, count(distinct(customer_id)) as customer_counts from tab2
where deposit > 1 and (purchase = 1 or withdrawal = 1) 
group by month_no;

--4
with monthly_balance_cte as (
	select customer_id, EXTRACT(MONTH FROM txn_date) as month_no, 
    to_char(txn_date, 'month') as month_name,
	sum(case when txn_type = 'deposit' then txn_amount else -txn_amount end) as cls_bal
	from customer_transactions
	group by customer_id, month_no, month_name), 
	
closing_bal_cte as (
	select customer_id, month_no, month_name,
	sum(cls_bal) over (partition by customer_id ORDER BY month_name) as runn_bal
	from monthly_balance_cte
	group by customer_id, month_no, month_name, cls_bal)	
				   
select * from closing_bal_cte;
			  
--5
WITH monthly_balance_cte as (
  SELECT customer_id,
         EXTRACT(MONTH FROM txn_date) AS month,
         SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS closing_balance
  FROM customer_transactions
  GROUP BY customer_id, month),
  
closingbalance_gt5_cte AS (
  SELECT customer_id, 
            sum(closing_balance) OVER (PARTITION BY customer_id ORDER BY month) as runn_bal
        FROM monthly_balance_cte
		group by customer_id, month,closing_balance),
		
percentage as (
	select distinct customer_id, 
	(last_bal - first_bal)*100 / first_bal as growing_perc from
	(select customer_id,
	first_value(runn_bal) OVER (PARTITION BY customer_id ORDER BY customer_id) as first_bal,
	last_value(runn_bal) OVER (PARTITION BY customer_id ORDER BY customer_id) as last_bal from closingbalance_gt5_cte) as transactions
order by customer_id)

select
	count(customer_id)*100/(select count(distinct customer_id) from customer_transactions)  as percentage
from percentage
where growing_perc > 5;

			  