declare @name varchar(100);
set @name = '%kappa%';

declare @TEMPORARY TABLE (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    value VARCHAR(255)
);

insert into @TEMPORARY (id, name, value) values (1, 'alpha', 'One');
insert into @TEMPORARY (id, name, value) values (2, 'beta', 'Two');
insert into @TEMPORARY (id, name, value) values (3, 'gamma', 'Three');
insert into @TEMPORARY (id, name, value) values (4, 'delta', 'Four');
insert into @TEMPORARY (id, name, value) values (5, 'epsilon', 'Five');
insert into @TEMPORARY (id, name, value) values (6, 'zeta', 'Six');
insert into @TEMPORARY (id, name, value) values (7, 'eta', 'Seven');
insert into @TEMPORARY (id, name, value) values (8, 'theta', 'Eight');
insert into @TEMPORARY (id, name, value) values (9, 'iota', 'Nine');
insert into @TEMPORARY (id, name, value) values (10, 'kappa', 'Ten');
insert into @TEMPORARY (id, name, value) values (11, 'lambda', 'Eleven');
insert into @TEMPORARY (id, name, value) values (12, 'mu', 'Twelve');
insert into @TEMPORARY (id, name, value) values (13, 'nu', 'Thirteen');
insert into @TEMPORARY (id, name, value) values (14, 'xi', 'Fourteen');
insert into @TEMPORARY (id, name, value) values (15, 'omicron', 'Fifteen');
insert into @TEMPORARY (id, name, value) values (16, 'pi', 'Sixteen');
insert into @TEMPORARY (id, name, value) values (17, 'rho', 'Seventeen');
insert into @TEMPORARY (id, name, value) values (18, 'sigma', 'Eighteen');
insert into @TEMPORARY (id, name, value) values (19, 'tau', 'Nineteen');
insert into @TEMPORARY (id, name, value) values (20, 'upsilon', 'Twenty');
insert into @TEMPORARY (id, name, value) values (21, 'phi', 'Twenty-One');
insert into @TEMPORARY (id, name, value) values (22, 'chi', 'Twenty-Two');
insert into @TEMPORARY (id, name, value) values (23, 'psi', 'Twenty-Three');
insert into @TEMPORARY (id, name, value) values (24, 'omega', 'Twenty-Four');

select * from @TEMPORARY
where name like '%' + @name + '%'
order by id asc;