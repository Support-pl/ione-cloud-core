<?php

/*
 * The MIT License
 *
 * Copyright 2015 Sergey Protasevich.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

namespace TinyApp\Controller;

use TinyApp\App;


/**
 * Base class for all controllers.
 */
abstract class AbstractController {

    protected $app;


    /**
     * Create an instance of controller.
     *
     * @param App $app the instance of application
     */
    public function __construct( App $app ) {
        $this->app = $app;
    }


    /**
     * Get a value by a key.
     *
     * @param string $key the key
     * @return mixed the value, or NULL if it is not set
     */
    protected function get( $key ) {
        return $this->app->get( $key );
    }


    /**
     * Define templates for actions.
     *
     * Override this method to define templates for actions of the controller.
     * Method must return associative array where keys are names of actions
     * without "Action" postfix and values are names of templates without
     * path to directory, prefix and postfix.
     *
     * @return array associative array of actions and templates
     * @see TinyApp\Service\IRenderingEngine
     * @see TinyApp\Service\AbstractRenderingEngine
     * @see TinyApp\Service\PHPRenderingEngine
     */
    public function defineTemplates() {}


}
