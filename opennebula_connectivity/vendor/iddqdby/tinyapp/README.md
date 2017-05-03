# Microframework for small command line applications

[![Build Status](https://travis-ci.org/iddqdby/tinyapp.svg?branch=master)](https://travis-ci.org/iddqdby/tinyapp)
[![Latest Stable Version](https://poser.pugx.org/iddqdby/tinyapp/v/stable)](https://packagist.org/packages/iddqdby/tinyapp)
[![Total Downloads](https://poser.pugx.org/iddqdby/tinyapp/downloads)](https://packagist.org/packages/iddqdby/tinyapp)
[![License](https://poser.pugx.org/iddqdby/tinyapp/license)](https://packagist.org/packages/iddqdby/tinyapp)

## Description

### Install the library

To install the library, run `composer require iddqdby/tinyapp`.

### Create an application

To create the application:
* Extend abstract class `TinyApp\App`
* Implement method `init()` to initialize your application
* Implement method `get($key)` to get services and other stuff from any dependency injection container you like
* Create a controller class that extends one of abstract classes in `TinyApp\Controller` namespace
* Create public action methods like "*something*Action"
* Define your controller in the dependency injection container under `App::CONTROLLER_PREFIX.App::CONTROLLER_MAIN` key
* Use protected method `get($key)` inside your actions to get services and other stuff from your dependency injection container
* Instantiate your app and call method `$app->run($action, $arguments)` to invoke an action once, or `$app->loop()` to run your application in interactive mode

### Example

Example of a script to run from CLI:

```php
<?php

require '/path/to/vendor/autoload.php';

$action = $argv[1];
$arguments = array_slice($argv, 2);

$app = new MyApp(); // MyApp extends TinyApp\App
$result = $app->run($action, $arguments);
printf("%s\n", $result);
```

The `$action` in the example above must match the regular expression `"/((?<CONTROLLER>[\w\d\_]+):)?(?<ACTION>[\w\d\_]+)/i"`.

Prefix `App::CONTROLLER_PREFIX` will be prepended to *CONTROLLER*. *CONTROLLER* will be set to `App::CONTROLLER_MAIN` if it is omitted.

Postfix `App::ACTION_POSTFIX` will be appended to *ACTION*.

The action of the controller will be invoked with passed arguments, and its result will be returned. The `\BadMethodCallException` exception will be thrown if no controller is registered under the given key, or if there is no such action in the controller.

## Requirements

PHP 5.4 or later.

## License

This program is licensed under the MIT License. See [LICENSE](LICENSE).
