use hardware;
select * from dim_customer;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;	
select * from fact_sales_monthly;

 /* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.*/

 select distinct market as Market_List, customer as Customer_Name, Region from dim_customer 
 where customer= 'AtliQ Exclusive' and region = 'APAC';


/*2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg*/ 

with unique_products_2020 as 
(select count(distinct p.product_code) as unique_products_2020 from dim_product p join fact_gross_price g on p.product_code = g.product_code
where g.fiscal_year = 2020) ,
unique_products_2021 as
( select count(distinct p.product_code)  as unique_products_2021 
 from dim_product p join fact_gross_price g on p.product_code = g.product_code
where g.fiscal_year = 2021) 
select unique_products_2020, unique_products_2021, round(((unique_products_2021 - unique_products_2020) / unique_products_2020)*100,2) as percentage_change 
from unique_products_2020, unique_products_2021;

/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains two fields:
- segment
- product_count */

 select segment, count(distinct product_code) as product_count from dim_product
 group by segment
 order by product_count desc;
 
 
/* 4.Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields:
- segment
- product_count_2020
- product_count_2021
- difference */

 with products_2020 as
 (select p.segment, count(distinct p.product_code) as product_count_2020 from dim_product p join fact_gross_price g 
 on p.product_code = g.product_code 
 where g.fiscal_year = 2020
  group by segment),
 products_2021 as
 ( select p.segment, count(distinct p.product_code) as product_count_2021 from dim_product p join fact_gross_price g 
 on p.product_code = g.product_code
 where g.fiscal_year = 2021
  group by segment)
 select products_2020.segment, products_2020.product_count_2020, products_2021.product_count_2021, (product_count_2021 - product_count_2020) as Difference from products_2020  join  products_2021
 on products_2020.segment = products_2021.segment
 group by  segment
 order by difference desc;
 
 
 /* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields:
- product_code
- product
- manufacturing_cost */

SELECT m.product_code, concat(product," (",variant,")") AS product, cost_year,manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p ON m.product_code = p.product_code
WHERE manufacturing_cost= 
(SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
or 
manufacturing_cost = 
(SELECT max(manufacturing_cost) FROM fact_manufacturing_cost) 
ORDER BY manufacturing_cost DESC;


/* 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields:
- customer_code
- customer
- average_discount_percentage */

select c.customer, c.customer_code, round((pre_invoice_discount_pct*100),2) as average_discount_percentage  
from dim_customer c join fact_pre_invoice_deductions p 
on c.customer_code = p.customer_code 
WHERE c.market = "India" AND fiscal_year = "2021"
and p.pre_invoice_discount_pct  > (select avg(pre_invoice_discount_pct) from fact_pre_invoice_deductions )
order by pre_invoice_discount_pct DESC
limit 5;
 
 
/* 7.Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions.
The final report contains these columns:
- Month
- Year
- Gross sales Amount */

select monthname(s.date) as month, s.fiscal_year as year, round(sum(s.sold_quantity*g.gross_price),0) as gross_sales_amount 
from fact_gross_price g 
join fact_sales_monthly s on g.product_code= s.product_code
join dim_customer c on s.customer_code= c.customer_code
where c.customer = 'Atliq Exclusive'
group by  month, year
order by month, year ;


/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields:
- sorted by the total_sold_quantity
- Quarter
- total_sold_quantity */

 WITH temp_table AS 
(
SELECT date,month(date_add(date,interval 4 month)) AS period, fiscal_year,sold_quantity 
FROM fact_sales_monthly
)
SELECT CASE 
   when period/3 <=1 then "Q1"
   when period/3 <=2 and period/3 > 1 then "Q2"
   when period/3 <=3 and period/3 > 2 then "Q3"
   when period/3 <=4 and period/3 > 3 then "Q4" END quarter,
 round(sum(sold_quantity)/1000000,2) as total_sold_quanity_in_millions FROM temp_table
WHERE fiscal_year = 2020
GROUP BY quarter
ORDER BY total_sold_quanity_in_millions DESC ;

 
 /*9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
 The final output contains these fields:
- channel,
- gross_sales_mln, 
- percentage */

WITH temp_table AS (
      SELECT c.channel,sum(s.sold_quantity * g.gross_price) AS total_sales
  FROM
  fact_sales_monthly s 
  JOIN fact_gross_price g ON s.product_code = g.product_code
  JOIN dim_customer c ON s.customer_code = c.customer_code
  WHERE s.fiscal_year= 2021
  GROUP BY c.channel
  ORDER BY total_sales DESC
)
SELECT 
  channel,
  round(total_sales/1000000,2) AS gross_sales_in_millions,
  round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM temp_table ;


/*10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields:
- division
- product_code
- product
- total_sold_quantity
- rank_order */

SELECT * FROM(
SELECT d.division,d.product_code,d.product,
SUM(f.sold_quantity) as total_sold_quantity,
rank() over(partition by d.division order by SUM(f.sold_quantity)) as rank_order FROM dim_product d
JOIN fact_sales_monthly f ON d.product_code=f.product_code
WHERE f.fiscal_year = 2021
GROUP BY d.division,d.product_code,d.product
) e
WHERE e.rank_order <=3;
 