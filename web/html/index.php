<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" type="text/css" href="style.css">
  <title>regexp -> automata</title>
</head>
<body>

  <?php $expr = $_GET['expr'] ?? ''; ?>

  <form>
    <input type="text" name="expr" placeholder="enter a regular expression" value="<?php echo $expr ?>">
    <input type="submit" value="generate">
  </form>

  <?php
    chdir(__DIR__);

    $descriptorspec = [
      0 => ['pipe', 'r'],
      1 => ['pipe', 'w'],
    ];

    $process = proc_open("./gensvg", $descriptorspec, $pipes);

    if (is_resource($process)) {
      fwrite($pipes[0], $expr);
      fclose($pipes[0]);
      $svg = stream_get_contents($pipes[1]);
      fclose($pipes[1]);
      proc_close($process);
      echo $svg;
    }
  ?>
  
</body>
</html>