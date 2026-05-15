-- 1 завдання: Побудуйте та зобразіть цільову метрику популярності продукту - кількості замовлень на продукт.
WITH filtered_orders AS (
  SELECT 
    o.order_id,
  FROM olist_store.orders o 
  WHERE order_status != 'canceled' AND order_status != 'unavailable'
  GROUP BY 1
),
  product_detail AS (
    SELECT 
      p.product_id,
      pt.string_field_0    AS name_in_portguesse,
      pt.string_field_1    AS name_in_english
    FROM olist_store.products p
     JOIN 
      olist_store.product_category_name_translation pt ON p.product_category_name = pt.string_field_0
  )

  SELECT 
    pd.name_in_english,
    COUNT(DISTINCT oi.order_id)    AS count_of_orders
  FROM olist_store.order_items oi
  INNER JOIN filtered_orders fo ON oi.order_id = fo.order_id
  INNER JOIN product_detail pd ON oi.product_id = pd.product_id
  GROUP BY 1
  ORDER BY 2 DESC
  LIMIT 10;


-- 2. Побудуйте та візуалізуйте опис основних факторів впливу на популярність продукту - характеристики продукту, ціна, попередній рейтинг, категорія та інші.

WITH product_price AS (
  SELECT
    order_id,
    AVG(price)   AS avg_price,
    product_id
  FROM olist_store.order_items oi
  GROUP BY 1,3   
  ),
product_avg_score AS (
  SELECT
    order_id,
    AVG(review_score) AS avg_score
  FROM olist_store.order_reviews os
  GROUP BY 1
),
  class_of_product AS (
    SELECT 
      product_id ,
      IFNULL(AVG(product_weight_g),0) AS avg_prod_weight,
      IFNULL(AVG(product_length_cm),0) AS avg_prod_lenght
    FROM olist_store.products p
    GROUP BY 1
),
  delivery_time AS (
    SELECT 
      DISTINCT order_id,
      DATE_DIFF(order_delivered_customer_date , order_purchase_timestamp, day) AS delivery_time_of_product
    FROM olist_store.orders o
  ) 

SELECT 
  p.product_category_name,
  COUNT(pp.order_id)                                    AS popularity_of_orders,
  ROUND(AVG(pp.avg_price),2)                            AS final_avg_price,
  ROUND(AVG(ps.avg_score),2)                            AS final_avg_score,
  ROUND(AVG(dt.delivery_time_of_product),2)             AS avg_delivery_time_of_product
FROM olist_store.products p
JOIN 
  product_price pp ON p.product_id = pp.product_id
JOIN 
  product_avg_score ps ON pp.order_id = ps.order_id
JOIN 
  class_of_product cp ON p.product_id = cp.product_id
JOIN
  delivery_time dt ON pp.order_id = dt.order_id
GROUP BY  p.product_category_name
ORDER BY 2 DESC
LIMIT 10;

-- 3.закономірність впливу факторів на цільову метрику

WITH product_price AS (
  SELECT
    order_id,
    AVG(price)   AS avg_price,
    product_id
  FROM olist_store.order_items oi
  GROUP BY 1,3   
  ),
product_avg_score AS (
  SELECT
    order_id,
    AVG(review_score) AS avg_score
  FROM olist_store.order_reviews os
  GROUP BY 1
),
  class_of_product AS (
    SELECT 
      product_id ,
      IFNULL(AVG(product_weight_g),0) AS avg_prod_weight,
      IFNULL(AVG(product_length_cm),0) AS avg_prod_lenght
    FROM olist_store.products p
    GROUP BY 1
),
  delivery_time AS (
    SELECT 
      DISTINCT order_id ,
      DATE_DIFF(order_delivered_customer_date , order_purchase_timestamp, day) AS delivery_time_of_product,
    FROM olist_store.orders o
  ),
clasification_of_delivery_time AS (
  SELECT 
    dt.order_id,
    dt.delivery_time_of_product,
    CASE
      WHEN delivery_time_of_product < 5 THEN 'Fast-delivery'
      WHEN delivery_time_of_product >=5 AND delivery_time_of_product <= 10 THEN 'Medium-delivery'
      WHEN delivery_time_of_product > 10 THEN 'Low-delivery'
    END AS class_of_delivery
  FROM delivery_time dt
)

SELECT
  CASE 
      WHEN pp.avg_price < 50 THEN 'Low-price'
      WHEN pp.avg_price BETWEEN 50 AND 100 THEN 'Medium-price'
      ELSE 'Big-price'
    END                                                             AS price_classification,
  IFNULL(cdt.class_of_delivery, "Unknown_type")                     AS classes_of_delivery,
  COUNT(DISTINCT o.order_id)                                        AS total_orders,
  ROUND(AVG(ps.avg_score), 2)                                       AS avg_group_score
FROM olist_store.orders o
  JOIN 
    delivery_time dt ON o.order_id = dt.order_id
  JOIN 
    clasification_of_delivery_time cdt ON o.order_id = cdt.order_id
  JOIN 
    product_price pp ON o.order_id = pp.order_id
  JOIN 
    product_avg_score ps ON pp.order_id = ps.order_id
GROUP BY 1,2
ORDER BY 1,2 DESC;

-- тут можна побачити багато закономірностей, приведу приклад : Чи правда якщо товари із великою ціною мають вищий середній бал чим із седеньою чи малою цінами. Така аномалія. Чи падає ксть замовлення у групі лів делівері порівняно із фаст делівері та чи дійсно, що лов прайс має більше замовлень чим біг прайс

--4.побудуйте сегментацію на базі найбільш впливових фактторів , яка дозволть відокремити  найпопулярніші продукти від найменш популярних

WITH product_price AS (
  SELECT
    order_id,
    AVG(price)   AS avg_price,
    product_id
  FROM olist_store.order_items oi
  GROUP BY 1,3   
  ),
product_avg_score AS (
  SELECT
    order_id,
    AVG(review_score) AS avg_score
  FROM olist_store.order_reviews os
  GROUP BY 1
),
  class_of_product AS (
    SELECT 
      product_id ,
      IFNULL(AVG(product_weight_g),0) AS avg_prod_weight,
      IFNULL(AVG(product_length_cm),0) AS avg_prod_lenght
    FROM olist_store.products p
    GROUP BY 1
),
  delivery_time AS (
    SELECT 
      DISTINCT order_id ,
      DATE_DIFF(order_delivered_customer_date , order_purchase_timestamp, day) AS delivery_time_of_product,
    FROM olist_store.orders o
  )

SELECT 
  CASE 
    WHEN pp.avg_price < 60 AND dt.delivery_time_of_product < 8 AND ps.avg_score > 4 THEN 'Good-products per delivery and score'
    WHEN  dt.delivery_time_of_product > 10 OR ps.avg_score < 3 THEN 'Bad  products'
    ELSE 'Common markets'
  END AS segments,
  COUNT(DISTINCT o.order_id) AS count_orders,
  ROUND(AVG(pp.avg_price), 2) AS avg_price,
  ROUND(AVG(ps.avg_score), 2) AS avg_score,
  ROUND(AVG(dt.delivery_time_of_product), 1) AS avg_delivery_days
FROM olist_store.orders o
 JOIN 
    delivery_time dt ON o.order_id = dt.order_id
  JOIN 
    product_price pp ON o.order_id = pp.order_id
  JOIN 
    product_avg_score ps ON pp.order_id = ps.order_id
GROUP BY segments
ORDER BY 2 DESC;







