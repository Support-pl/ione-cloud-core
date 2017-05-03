<?php if( isset( $data['error'] ) ):?>
<h1>FAIL TO ADD IP(s)<br>REASON:<br><?=$data['error']?></h1>
<hr>
<?php endif?>

<h2>Add single IP</h2>
<form action="<?=$_SERVER['REQUEST_URI']?>" method="post">
  IP:<br>
  <input type="text" name="ip"><br>
  Tags:<br>
  <input type="text" name="tags"><br>
  <input type="hidden" name="submit_type" value="single">
  <input type="submit" value="Add">
</form>
<hr>

<h2>Add IP range</h2>
<form action="<?=$_SERVER['REQUEST_URI']?>" method="post">
  First IP:<br>
  <input type="text" name="ip"><br>
  Amount:<br>
  <input type="text" name="amount"><br>
  Tags:<br>
  <input type="text" name="tags"><br>
  <input type="hidden" name="submit_type" value="range">
  <input type="submit" value="Add">
</form>
<hr>

<table class="datatable">
	<thead>
		<tr>
			<th>Tags</th>
			<th>IP</th>
			<th>Services</th>
		</tr>
	</thead>
	<tbody>
	<?php foreach( $data['IPs'] as $ip_info ):?>
		<tr>
			<td><?=$ip_info['tags']?></td>
			<td><?=$ip_info['IP']?></td>
			<td><?=$ip_info['service_uris']?></td>
		</tr>
	<?php endforeach?>
	</tbody>
</table>
