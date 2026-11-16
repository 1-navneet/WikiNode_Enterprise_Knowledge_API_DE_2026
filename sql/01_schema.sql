-- Database Schema

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE articles (
    article_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category_id INTEGER NOT NULL,
    CONSTRAINT fk_article_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
);