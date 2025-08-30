-- QUESTION 1: What is the total amount each customer spent at the restaurant?
/*
DESCRIPTION: Total amount each customer spent at the restaurant
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

SELECT
	s.customer_id,
	SUM(m.price) AS total_amount
FROM
	sales s
INNER JOIN
	menu m ON s.product_id = m.product_id
GROUP BY
	s.customer_id
ORDER BY
	total_amount DESC;


-- QUESTION 2: How many days has each customer visited the restaurant?
/*
DESCRIPTION: Distinct visit days per customer
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

SELECT
	s.customer_id,
	COUNT(DISTINCT s.order_date) AS visit_count 
FROM
	sales s
GROUP BY
	s.customer_id
ORDER BY
	visit_count DESC;


-- QUESTION 3: What was the first item from the menu purchased by each customer?
/*
DESCRIPTION: First item from the menu purchased by each customer
NOTE: Handles same-day purchases using product_id ASC as deterministic tiebreaker
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

WITH first_purchase AS (
	SELECT
		s.customer_id,
		m.product_id,
		m.product_name,
		s.order_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY
		s.order_date ASC, s.product_id ASC) AS rn
	FROM
		sales s
	JOIN
		menu m ON s.product_id = m.product_id
)
SELECT
	customer_id,
	product_name,
	order_date
FROM
	first_purchase
WHERE
	rn = 1
ORDER BY
	order_date;


-- QUESTION 4: What is the most purchased item on the menu and how many times was it purchased by all customers?
/*
DESCRIPTION: Most purchased item on the menu and how many times it was purchased by customers.
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

SELECT
	m.product_id,
	m.product_name,
	COUNT(*) AS purchase_count
FROM 
	menu m
INNER JOIN
	sales s ON m.product_id = s.product_id
GROUP BY
	m.product_id, m.product_name
ORDER BY
	purchase_count DESC
LIMIT 1;


-- QUESTION 5: Which item was the most popular for each customer?
/*
DESCRIPTION: Most popular item for each customer
NOTE: Multiple items purchased by customer B with the same purchase count.
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

WITH item_rank AS (
	SELECT
		s.customer_id,
		m.product_name,
		COUNT(s.product_id) AS purchase_count,
		RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS popularity_rank 
	FROM
		sales s
	INNER JOIN
		menu m ON s.product_id = m.product_id
	GROUP BY
		s.customer_id, s.product_id, m.product_name
)

SELECT
	customer_id,
	product_name,
	purchase_count
FROM
	item_rank 
WHERE
	popularity_rank = 1;


-- QUESTION 6: Which item was purchased first by the customer after they became a member?
/*
DESCRIPTION: First item purchased by customer after they became a member.
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/
WITH purchased_order AS (
	SELECT 
		s.customer_id,
		s.product_id,
		m.product_name AS first_item,
		s.order_date,
		ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.order_date ASC, s.product_id ASC) AS purchased_order
	FROM
		sales s 
	INNER JOIN
		members mb ON s.customer_id = mb.customer_id
	INNER JOIN
		menu m ON s.product_id = m.product_id
	WHERE
		s.order_date >= mb.join_date
)

SELECT
	customer_id,
	first_item
FROM
	purchased_order
WHERE
	purchased_order = 1;


-- QUESTION 7: Which item was purchased just before the customer became a member?
/*
DESCRIPTION: Last item purchased before membership enrollment
NOTE: Handles same-day purchases using product_id ASC as deterministic tiebreaker
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/
WITH pre_membership_purchases AS (SELECT 
	s.customer_id,
	m.product_name,
	s.order_date,
	ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC, s.product_id ASC) AS recency_rank
FROM
	sales s 
INNER JOIN
	members mb ON s.customer_id = mb.customer_id
INNER JOIN
	menu m ON s.product_id = m.product_id
WHERE
	s.order_date < mb.join_date
)

SELECT
	customer_id,
	product_name
FROM
	pre_membership_purchases
WHERE
	recency_rank = 1;


-- QUESTION 8: What is the total items and amount spent for each member before they became a member?
/*
DESCRIPTION: Total items and amount spent for each member before they became a member
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

SELECT
	s.customer_id,
	COUNT(*) AS total_items,
	SUM(m.price) AS total_amount
FROM
	sales s
INNER JOIN
	members mb ON s.customer_id = mb.customer_id
INNER JOIN
	menu m ON s.product_id = m.product_id
WHERE
	s.order_date < mb.join_date
GROUP BY
	s.customer_id
ORDER BY
	s.customer_id;



-- QUESTION 9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
/*
DESCRIPTION: Total points each customer would have if every $1 spent equals 10 points and sushi had a 2x points multiplier.
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

WITH customer_points AS (
	SELECT
		s.customer_id,
		m.price * 10 * CASE
			WHEN m.product_id = 1 THEN 2
			ELSE 1
		END AS points
	FROM
		sales s
	INNER JOIN
		menu m ON s.product_id = m.product_id
)

SELECT 
	customer_id,
	SUM(points) AS total_points
FROM
	customer_points
GROUP BY
	customer_id
ORDER BY
	total_points DESC;

-- QUESTION 10: In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
/*
DESCRIPTION: Customer A and B points through January with 2x multiplier during first week of membership
OWNER: Pedro Palmier
CREATED: 2025-08-29
*/

WITH customer_points AS (
	SELECT
		s.customer_id,
		s.order_date,
		mb.join_date,
		m.product_id,
		CASE
			WHEN s.order_date BETWEEN mb.join_date AND mb.join_date + 6 THEN m.price * 10 * 2 
			ELSE m.price * 10 * CASE
				WHEN m.product_id = 1 THEN 2
				ELSE 1
			END
		END AS points
	FROM
		sales s
	INNER JOIN
		menu m ON s.product_id = m.product_id
	INNER JOIN
		members mb ON s.customer_id = mb.customer_id
	WHERE
		s.order_date >= mb.join_date
		AND	s.order_date BETWEEN '2021-01-01' AND '2021-01-31'
		AND s.customer_id IN ('A','B')
)

SELECT 
	customer_id,
	SUM(points) AS total_points
FROM
	customer_points
GROUP BY
	customer_id
ORDER BY
	total_points DESC;