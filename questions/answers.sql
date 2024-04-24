-- PART 2A(I)

-- Retrieve the most ordered product in successful orders
SELECT
    li.item_id AS product_id,                               -- Product ID from line_items table
    p.name AS product_name,                                  -- Product name from products table
    SUM(li.quantity) AS num_times_in_successful_orders  -- Sum of product quantities in successful orders
FROM 
    alt_school.events e                                     -- Events table
JOIN 
    alt_school.orders o ON e.customer_id = o.customer_id    -- Join events with orders on customer ID
JOIN 
    alt_school.line_items li ON o.order_id = li.order_id     -- Join orders with line_items on order ID
JOIN 
    alt_school.products p ON li.item_id = p.id              -- Join line_items with products on product ID
WHERE 
    e.event_data ->> 'status' = 'success'                  -- Filter successful events
GROUP BY 
    li.item_id, p.name                                     -- Group by product ID and name
ORDER BY 
    num_times_in_successful_orders DESC                    -- Sort by sum of quantities in descending order
LIMIT 1;                                                    -- Limit to the most ordered product


-- PART 2A(ii): top five spenders

-- Common Table Expression (CTE) to select distinct customer IDs who successfully checked out
WITH successful_checkouts AS (
    SELECT DISTINCT e.customer_id
    FROM alt_school.events e
    WHERE e.event_data ->> 'status' = 'success' -- Filter for successful checkouts
),
-- CTE to retrieve details of items added to cart by customers during successful checkouts
customer_spendings AS (
    SELECT e.customer_id,
           CAST(e.event_data ->> 'item_id' AS INTEGER) AS item_id, -- Cast item_id to INTEGER
           CAST(e.event_data ->> 'quantity' AS INTEGER) AS quantity, -- Cast quantity to INTEGER
           p.price -- Get price of the item from products table
    FROM alt_school.events e
    JOIN alt_school.products p ON CAST(e.event_data ->> 'item_id' AS INTEGER) = p.id -- Join with products table
    JOIN successful_checkouts s ON e.customer_id = s.customer_id -- Join with successful_checkouts CTE
    WHERE e.event_data ->> 'event_type' IN ('add_to_cart', 'remove_from_cart') -- Filter for add/remove cart events
),
-- CTE to calculate total spending per customer
customer_total_spendings AS (
    SELECT customer_id,
           SUM(quantity * price) AS total_spend -- Calculate total spending by multiplying quantity with price and summing up
    FROM customer_spendings
    GROUP BY customer_id -- Group by customer ID
)
-- Main query to retrieve customer ID, location, and total spending, sorted by total spending in descending order
SELECT cts.customer_id,
       c.location,
       cts.total_spend AS total_spend -- Alias total_spend for clarity
FROM customer_total_spendings cts
JOIN alt_school.customers c ON cts.customer_id = c.customer_id -- Join with customers table to get location
ORDER BY total_spend DESC -- Order by total spending in descending order
LIMIT 5; -- Limit the result to top 5 spenders



-- PART 2B(i): 

SELECT location, checkout_count
FROM (
    SELECT c.location, COUNT(*) AS checkout_count
    FROM alt_school.events e
    JOIN alt_school.customers c ON e.customer_id = c.customer_id
    WHERE e.event_data ->> 'status' = 'success'
    GROUP BY c.location
) AS subquery
ORDER BY checkout_count DESC
LIMIT 1;


-- PART 2B(ii)

-- Select customer_id and count of events excluding visits and checkouts
SELECT 
    customer_id,
    COUNT(*) AS num_events
FROM 
    alt_school.events
-- Filter out events that are not visits or checkouts
WHERE 
    event_data ->> 'event_type' NOT IN ('visit', 'checkout')
    -- Select customers who removed items from their cart but didn't check out
    AND customer_id IN (
        -- Subquery to select customer_id who removed items from cart
        SELECT 
            customer_id
        FROM 
            alt_school.events
        -- Filter to select events where items were removed from cart
        WHERE 
            event_data ->> 'event_type' = 'remove_from_cart'
            -- Exclude customers who checked out
            AND customer_id NOT IN (
                -- Subquery to select customer_id who checked out
                SELECT 
                    customer_id
                FROM 
                    alt_school.events
                -- Filter to select events where customers checked out
                WHERE 
                    event_data ->> 'event_type' = 'checkout'
            )
    )
-- Group the results by customer_id
GROUP BY 
    customer_id
-- Order the results by the count of events in descending order
ORDER BY 
    COUNT(*) DESC;
    
    
-- PART 2B(iii) 

-- Common Table Expression (CTE) to filter successful checkouts
WITH completed_checkouts AS (
    -- Selecting customer IDs who completed a checkout
    SELECT 
        customer_id
    FROM 
        alt_school.events
    WHERE 
        event_data ->> 'event_type' = 'checkout'
),
-- Main query to calculate the average number of visits per customer
average_visits_per_customer AS (
    -- Counting visits per customer who completed a checkout
    SELECT 
        e.customer_id,
        COUNT(*) AS num_visits
    FROM 
        alt_school.events e
    INNER JOIN 
        completed_checkouts c ON e.customer_id = c.customer_id
    WHERE 
        event_data ->> 'event_type' = 'visit'
    GROUP BY 
        e.customer_id
)
-- Final query to calculate the average visits across all customers
SELECT 
    ROUND(AVG(num_visits)::numeric, 2) AS average_visits
FROM 
    average_visits_per_customer;