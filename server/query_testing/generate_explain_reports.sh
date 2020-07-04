#!/bin/bash
set -e

# You can import these to http://tatiyants.com/pev/#/plans/new

# Do the views first

echo "explain (analyze, format json) select * from user_mview" > explain.sql
psql -qAt -U lemmy -f explain.sql > user_view.json

echo "explain (analyze, format json) select * from post_fast where user_id is null order by hot_rank desc, published desc" > explain.sql
psql -qAt -U lemmy -f explain.sql > post_fast.json

echo "explain (analyze, format json) select * from comment_mview where user_id is null" > explain.sql
psql -qAt -U lemmy -f explain.sql > comment_view.json

echo "explain (analyze, format json) select * from community_mview where user_id is null order by hot_rank desc" > explain.sql
psql -qAt -U lemmy -f explain.sql > community_view.json

echo "explain (analyze, format json) select * from site_view limit 1" > explain.sql
psql -qAt -U lemmy -f explain.sql > site_view.json

echo "explain (analyze, format json) select * from reply_view where user_id = 34 and recipient_id = 34" > explain.sql
psql -qAt -U lemmy -f explain.sql > reply_view.json

echo "explain (analyze, format json) select * from user_mention_view where user_id = 34 and recipient_id = 34" > explain.sql
psql -qAt -U lemmy -f explain.sql > user_mention_view.json

echo "explain (analyze, format json) select * from user_mention_mview where user_id = 34 and recipient_id = 34" > explain.sql
psql -qAt -U lemmy -f explain.sql > user_mention_mview.json

grep "Execution Time" *.json

rm explain.sql
