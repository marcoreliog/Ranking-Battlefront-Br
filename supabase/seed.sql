-- Idempotent canonical hero seed. This is safe to run repeatedly.
insert into public.heroes (name, slug, side) values
('Luke Skywalker','luke-skywalker','light'),('Leia Organa','leia-organa','light'),('Han Solo','han-solo','light'),('Chewbacca','chewbacca','light'),('Lando Calrissian','lando-calrissian','light'),('Rey','rey','light'),('Yoda','yoda','light'),('Obi-Wan Kenobi','obi-wan-kenobi','light'),('Anakin Skywalker','anakin-skywalker','light'),('Finn','finn','light'),('BB-8','bb-8','light'),
('Darth Vader','darth-vader','dark'),('Imperador Palpatine','imperador-palpatine','dark'),('Kylo Ren','kylo-ren','dark'),('Darth Maul','darth-maul','dark'),('Boba Fett','boba-fett','dark'),('Bossk','bossk','dark'),('Iden Versio','iden-versio','dark'),('Capitã Phasma','capita-phasma','dark'),('General Grievous','general-grievous','dark'),('Conde Dookan','conde-dookan','dark'),('BB-9E','bb-9e','dark')
on conflict (slug) do update set name=excluded.name, side=excluded.side;
