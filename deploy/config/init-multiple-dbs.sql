-- 建立 ffm-hub 專用使用者與資料庫
CREATE USER admin WITH PASSWORD 'admin';
CREATE DATABASE "afs-hub_db" OWNER admin;
GRANT ALL PRIVILEGES ON DATABASE "afs-hub_db" TO admin;
