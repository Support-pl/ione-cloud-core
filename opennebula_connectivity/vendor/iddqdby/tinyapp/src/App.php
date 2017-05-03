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

namespace TinyApp;

use Throwable;
use Exception;
use BadMethodCallException;
use TinyApp\Service\RenderingEngine\IRenderingEngine;


/**
 * Base class for applications.
 */
abstract class App {

    /** Prefix for keys to register controllers */
    const CONTROLLER_PREFIX = 'controller:';

    /** Name of the main (default) controller */
    const CONTROLLER_MAIN = 'main';

    /** Key to register custom rendering engine */
    const RENDERING_ENGINE_KEY = 'rendering_engine';

    /** Postfix for action methods of controllers */
    const ACTION_POSTFIX = 'Action';


    private $stdout = null;
    private $stderr = null;


    /**
     * Create new instance of the application.
     */
    public function __construct() {
        $this->init();
    }


    /**
     * Run an action.
     *
     * @param string $action_name action name
     * @param array $arguments arguments to pass to the action
     * @return mixed a result of the action
     * @throws BadMethodCallException if the action does not exist
     */
    public function run( $action_name, array $arguments = [] ) {
        $matches = [];
        preg_match( '/((?<CONTROLLER>[\w\d_]+):)?(?<ACTION>[\w\d_]+)/iu', $action_name, $matches );

        $controller_name = empty( $matches['CONTROLLER'] ) ? self::CONTROLLER_MAIN : $matches['CONTROLLER'];
        $action_subname = $matches['ACTION'];
        $method_name = $action_subname.self::ACTION_POSTFIX;

        $controller = $this->get( self::CONTROLLER_PREFIX.$controller_name );
        $action = [$controller, $method_name];

        if( !is_callable( $action ) ) {
            throw new BadMethodCallException( sprintf(
                'Action "%s" of controller "%s" does not exist', $action_subname, $controller_name ) );
        }

        $result = call_user_func_array( $action, $arguments );

        $rendering_engine = $this->get( self::RENDERING_ENGINE_KEY );
        $action_to_template_map = method_exists( $controller, 'defineTemplates' )
            ? (array)$controller->defineTemplates()
            : [];

        if(
            !$rendering_engine instanceof IRenderingEngine
            ||
            !array_key_exists( $action_subname, $action_to_template_map )
        ) {
            return $result;
        }

        $template_name = strval( $action_to_template_map[ $action_subname ] );

        return $rendering_engine->render( $result, $template_name );
    }


    /**
     * Run application in interactive mode.
     */
    public function loop() {
        while( 'exit' !== $line = readline( '> ' ) ) {

            $args = explode( ' ', trim( preg_replace( '/\s+/', ' ', $line ) ) );
            if( empty( $args[0] ) ) {
                $this->stderr( 'Usage: <action> <arg1> <arg2> ... <argN>, or "exit" to terminate' );
                continue;
            }

            try {
                $result = $this->run( $args[0], array_slice( $args, 1 ) );
                $this->stdout( is_scalar( $result ) || method_exists( $result, '__toString' )
                        ? $result
                        : var_export( $result, true ) );
            } catch( Exception $ex ) {
                $this->handleException( $ex );
            } catch( Throwable $ex ) { // for PHP >= 7.0
                $this->handleException( $ex );
            }
        }
    }


    /**
     * Send string to STDOUT.
     *
     * @param string $line the string
     */
    public function stdout( $line ) {
        $this->out( 'php://stdout', $line );
    }


    /**
     * Send string to STDERR.
     *
     * @param string $line the string
     */
    public function stderr( $line ) {
        $this->out( 'php://stderr', $line );
    }


    private function out( $stream, $line ) {
        switch( $stream ) {
            case 'php://stdout':
                $handle = &$this->stdout;
                break;
            case 'php://stderr':
                $handle = &$this->stderr;
                break;
        }
        if( !$handle ) {
            $handle = fopen( $stream, 'a' );
        }
        fwrite( $handle, $line."\n" );
    }


    /**
     * Get a value by a key.
     *
     * @param string $key the key
     * @return mixed the value, or NULL if it is not set
     */
    public abstract function get( $key );


    /**
     * Initialize the application.
     */
    protected abstract function init();


    private function handleException( $ex ) {
        $this->stderr( sprintf( "Unexpected exception:\n%s", $ex ) );
    }


    public function __destruct() {
        if( $this->stdout ) {
            fclose( $this->stdout );
        }
        if( $this->stderr ) {
            fclose( $this->stderr );
        }
    }

}
