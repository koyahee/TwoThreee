declare @name varchar(100);
set @name = '';

declare @value varchar(100); /* %:,One: One, Two: Two */
set @value = '%';

 declare @not_used varchar(100);
 set @not_used = '%';

declare @TEMPORARY TABLE (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    value VARCHAR(255),
    text_decoration_TextDecolation VARCHAR(255),
    start_process_StartProcess VARCHAR(255)
);

insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (1, 'alpha', 'One', '<span style="color:red;">red</span>','[![image not found](./img/image.png)](notepad)');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (2, 'beta', 'Two', '<span style="color:blue;">blue</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (3, 'gamma', 'Three', '<span style="color:green;">green</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (4, 'delta', 'Four', '<span style="color:yellow;">yellow</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (5, 'epsilon', 'Five', '<span style="color:orange;">orange</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (6, 'zeta', 'Six', '<span style="color:pink;">pink</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (7, 'eta', 'Seven', '<span style="color:purple;">purple</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (8, 'theta', 'Eight', '<span style="color:black;">black</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (9, 'iota', 'Nine', '<span style="color:white;">white</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (10, 'kappa', 'Ten', '<span style="color:gray;">gray</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (11, 'lambda', 'Eleven', '<span style="color:brown;">brown</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (12, 'mu', 'Twelve', '<span style="color:beige;">beige</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (13, 'nu', 'Thirteen', '<span style="color:cyan;">cyan</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (14, 'xi', 'Fourteen', '<span style="color:magenta;">magenta</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (15, 'omicron', 'Fifteen', '<span style="color:violet;">violet</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (16, 'pi', 'Sixteen', '<span style="color:indigo;">indigo</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (17, 'rho', 'Seventeen', '<span style="color:teal;">teal</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (18, 'sigma', 'Eighteen', '<span style="color:turquoise;">turquoise</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (19, 'tau', 'Nineteen', '<span style="color:coral;">coral</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (20, 'upsilon', 'Twenty', '<span style="color:gold;">gold</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (21, 'phi', 'Twenty-One', '<span style="color:silver;">silver</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (22, 'chi', 'Twenty-Two', '<span style="color:lavender;">lavender</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (23, 'psi', 'Twenty-Three', '<span style="color:maroon;">maroon</span>','notepad');
insert into @TEMPORARY (id, name, value, text_decoration_TextDecolation, start_process_StartProcess) values (24, 'omega', 'Twenty-Four', '<span style="color:olive;">olive</span>','notepad');

select * from @TEMPORARY
where name like '%' + @name + '%'
and value like '%' + @value + '%'
order by id asc;