--1. Fetch all the paintings which are not displayed on any museums?
select name 
from work
where museum_id is NULL

--2. Are there museums without any paintings?
select *
from museum m 
where not exists (select 1 from work w where m.museum_id = w.museum_id )


--3. How many paintings have an asking price of more than their regular price?
select count(*)
from product_size
where sale_price > regular_price


--4. Identify the paintings whose asking price is less than 50% of its regular price
select count(*)
from product_size
where sale_price > (regular_price*0.5)


--5. Which canva size costs the most?
select c.label, ps.sale_price
from (select *, rank() over(order by sale_price desc)rnk
	  from product_size) ps
left join canvas_size c on c.size_id::text=ps.size_id
where ps.rnk=1
	  

--6. Delete duplicate records from work, product_size, subject and image_link tables
delete from work
	where ctid not in(
		select min(ctid)
		from work
		group by work_id)
	
delete from product_size
	where ctid not in(
		select min(ctid)
		from product_size
		group by work_id,size_id)

delete from subject
	where ctid not in(
		select min(ctid)
		from subject
		group by work_id,subject)


delete from image_link
	where ctid not in(
		select min(ctid)
		from image_link
		group by work_id)


--7. Identify the museums with invalid city information in the given dataset
select name,city
from museum
where city ~ '^[0-9]'


--8. Museum_Hours table has 1 invalid entry. Identify it and remove it.
delete from museum_hours
	where ctid not in(
		select min(ctid)
		from museum_hours
		group by museum_id,day)
					
--9. Fetch the top 10 most famous painting subject
select s.subject, count(s.subject) as count
from subject s
join work w on s.work_id = w.work_id
group by s.subject
order by count(s.subject) desc
limit 10


--10. Identify the museums which are open on both Sunday and Monday. Display museum name, city.
select m.name,m.city
from museum m
left join museum_hours mh on m.museum_id = mh.museum_id
where mh.day ='Sunday'
and exists (select name, city from museum_hours mh
		where mh.museum_id = m.museum_id and mh.day='Monday')
		   
		   
--11. How many museums are open every single day?
select m.name
from museum m
left join museum_hours mh on m.museum_id = mh.museum_id
where mh.day in ('Sunday','Monday','Tuesday','Wednesday','Friday','Thursday','Saturday')
group by m.name
having count(distinct mh.day)=7


--12. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
select m.name, count(w.work_id) as number_of_paintings
from museum m
left join work w on m.museum_id = w.museum_id
group by m.name
order by count(w.work_id) desc
limit 5


--13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an
select full_name,nationality,number_of_paintings 
from
(select a.artist_id, a.full_name, a.nationality, count(w.artist_id) as number_of_paintings, 
 	ank() over(order by count(a.artist_id) desc)rnk
	from work w
	left join artist a on w.artist_id=a.artist_id
	group by a.artist_id, a.full_name,a.nationality) x
where rnk<=5


--14. Display the 3 least popular canva sizes								
select label, number_of_paintings, rnk
from
(select c.label, c.size_id, count(1) as number_of_paintings,
 	dense_rank()over(order by count(p.work_id))rnk
	from canvas_size c
	inner join product_size p on c.size_id::text=p.size_id
	inner join work w on p.work_id=w.work_id
	group by c.size_id,c.label) x
where x.rnk<=3


--15. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day
select name, state,day,duration from										
(select name, state, day, open, close, to_timestamp(open,'HH:MI AM'), to_timestamp(close,'HH:MI PM'),
	to_timestamp(close,'HH:MI PM')-to_timestamp(open,'HH:MI AM') as duration,
	ank()over(order by to_timestamp(close,'HH:MI PM')-to_timestamp(open,'HH:MI AM') desc) rnk 
	from museum_hours mh
	join museum m on mh.museum_id = m.museum_id)x
where x.rnk = 1


--16. Which museum has the most no of most popular painting style?
select name,style, total
from											
(select w.style, count(1) as total, m.name,rank()over(order by count(1) desc) rnk
from work w
join museum m on w.museum_id = m.museum_id
group by w.style,m.name) x
where x.rnk =1


--17. Identify the artists whose paintings are displayed in multiple countries
with cte as(
	select distinct a.full_name as artist, m.country
	from artist a
	join work w on a.artist_id = w.artist_id
	join museum m on m.museum_id = w.museum_id)
select artist, count(country) as number_of_countries
from cte
group by artist
having count(distinct country) >1
order by number_of_countries desc



--18. Identify the artist and the museum where the most expensive and least expensive painting is placed. 
	Display the artist name, sale_price, painting name, museum name, museum city and canvas label
with cte as 
	(select *
		,rank() over(order by sale_price desc) as rnk_first
		,rank() over(order by sale_price ) as rnk_last
		 from product_size)
select a.full_name as artist,m.name as museum_name,m.city as city,w.name as painting,cs.label as canvas_label,cte.sale_price as sale_price
from cte
join work w on w.work_id = cte.work_id
join museum m on m.museum_id = w.museum_id
join artist a on w.artist_id=a.artist_id
join canvas_size cs on cte.size_id = cs.size_id::text
where rnk_first=1 or rnk_last=1


--19. Which country has the 5th highest no of paintings?
select country, number_of_paintings
from
(select m.country as country, count(w.work_id) as number_of_paintings, rank()over(order by count(w.work_id) desc) rnk
from work w
join museum m on m.museum_id = w.museum_id
group by m.country) x
where x.rnk =5


--20. Which are the 3 most popular and 3 least popular painting styles?
with cte as 
	(select style, count(1) as cnt
	, rank() over(order by count(1) desc) rnk
	, count(1) over() as no_of_records
	from work
	where style is not null
	group by style)
select style
	, case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks 
from cte
where rnk <=3
or rnk > no_of_records - 3;


-- 21) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.
select full_name as artist, nationality, number_of_paintings
from (
	select a.full_name, a.nationality
	,count(1) as no_of_paintings
	,rank() over(order by count(1) desc) as rnk
	from work w
	join artist a on a.artist_id=w.artist_id
	join subject s on s.work_id=w.work_id
	join museum m on m.museum_id=w.museum_id
	where s.subject='Portraits'
	and m.country != 'USA'
	group by a.full_name, a.nationality) x
where rnk=1;	
