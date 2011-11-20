<?php

error_reporting(E_ALL);

$mysqlUsername = 'root';
$mysqlPassword = '';
$mysqlDatabase = 'orderby_injection';

$connectResult = mysql_connect('localhost', $mysqlUsername, $mysqlPassword);
if( !$connectResult ) die('Could not connect');
$selectResult = mysql_select_db($mysqlDatabase);
if( !$selectResult ) die('Could not select DB');

$sql = 'SELECT * FROM `user`';
if( !empty($_GET['order']) ) {
  $sql .= ' ORDER BY ' . $_GET['order'];
}

$result = mysql_query($sql);
if( !$result ) die(mysql_error());
?>
<table border="1">
  <thead>
    <tr>
      <th><a href="?order=id">id</a></th>
      <th><a href="?order=username">username</a></th>
    </tr>
  </thead>
  <tbody>
<?php
while( $row = mysql_fetch_assoc($result) ) {
?>
    <tr>
      <td><?php echo $row['id']-1; ?></td>
      <td><?php echo $row['username']; ?></td>
    </tr>
<?php
}
?>
  </tbody>
</table>
