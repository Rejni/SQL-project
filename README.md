# SQL-project

SQL projects on one sales dataset (customers, products, sales), from raw data to business insights:

1. **Project 01** builds a data warehouse: it imports the raw CRM and ERP files, cleans them, and creates the tables `dim_customers`, `dim_products` and `fact_sales`.
2. **Project 02** analyses these tables: sales performance, customer behavior and product trends.

```text
 raw CSV files ──► Project 01: data warehouse ──► dim_customers, dim_products, fact_sales ──► Project 02: analytics
                   (bronze → silver → gold)                                                    (reports, KPIs)
```

## Repository structure

```text
SQL-project/
├── Project 01/
│   └── sql-data-cleaning-project/
│       ├── 01_datasets/        raw CSV files (CRM, ERP)
│       ├── 02_docs/            data model picture
│       ├── 03_scripts/         bronze, silver, gold SQL scripts
│       ├── 04_tests/           quality checks
│       └── README.md
├── Project 02/
│   ├── Database/               dim_customers, dim_products, fact_sales (CSV)
│   ├── MySQL/                  7 SQL analyses
│   ├── PostgreSQL/             7 SQL analyses
│   └── README.md
└── README.md
```

## Project 01: Data Warehouse and Data Cleaning (MySQL)

A data warehouse built in **MySQL 8** with the **Medallion architecture** (bronze → silver → gold). The focus is on data cleaning: finding quality problems in raw data, fixing them, and checking the result.

- **Bronze:** imports 6 CSV files from two source systems (CRM and ERP) as they are.
- **Silver:** cleans every column: duplicates, missing values, extra spaces, codes, wrong dates, wrong sales amounts, different ID formats.
- **Gold:** joins the cleaned tables into a star schema: `dim_customers`, `dim_products`, `fact_sales`.
- **Tests:** quality checks for every column after cleaning and for the joins.

→ [Project 01: SQL Data Cleaning](Project%2001/sql-data-cleaning-project)

## Project 02: SQL Data Analytics (PostgreSQL and MySQL)

Seven analyses of the sales data, each written for **PostgreSQL** and **MySQL**: magnitude, ranking, time-based, cumulative and segmentation analysis, plus customer and product reports.

→ [Project 02: SQL Data Analytics](Project%2002)
