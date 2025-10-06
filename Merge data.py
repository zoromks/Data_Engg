# Databricks notebook source
# MAGIC %sql
# MAGIC create table item_data(
# MAGIC   id int,
# MAGIC   name varchar(10),
# MAGIC   cost int
# MAGIC );
# MAGIC create table order_data(
# MAGIC   oid int,
# MAGIC   name varchar(10),
# MAGIC   cost int
# MAGIC );
# MAGIC

# COMMAND ----------

# MAGIC %sql
# MAGIC insert into item_data values(1,'item1',100),(2,'item2',200),(3,'item3',300);
# MAGIC insert into order_data values(3,'item1',100),(2,'item2',200),(4,'item3',300);

# COMMAND ----------

# MAGIC %sql
# MAGIC merge into order_data od
# MAGIC using item_data id
# MAGIC on od.oid = id.id
# MAGIC when matched then update set od.cost = id.cost+od.cost
# MAGIC when not matched then insert (oid, name, cost) values (id.id, id.name, id.cost)

# COMMAND ----------

# MAGIC %sql
# MAGIC select * from order_data