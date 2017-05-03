<?php

/*
 * The MIT License
 *
 * Copyright 2016 Sergey Protasevich.
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

namespace TinyApp\Service\RenderingEngine;

use TinyApp\Service\RenderingEngine\AbstractRenderingEngine;
use Throwable;
use Exception;
use TinyApp\Exception\TemplateException;


/**
 * Rendering engine uses regular PHP templates.
 */
class PHPRenderingEngine extends AbstractRenderingEngine {


    private $error_types;


    public function __construct( $error_types = null ) {

        if( null === $error_types ) {
            $error_types = E_ALL | E_STRICT;
        }

        $this->error_types = $error_types;

        $this->setTemplatePostfix( '.php' );
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\AbstractRenderingEngine::doRender()
     */
    protected function doRender( $data, $template_path ) {

        set_error_handler( function ( $errno, $errstr, $errfile, $errline ) use ( $template_path ) {
            throw new TemplateException(
                    sprintf( 'Unexpected error while rendering template %s. Error: %s %s. File: %s:%s.',
                    $template_path, $errno, $errstr, $errfile, $errline ) );
        }, $this->error_types );

        try {

            $result = self::staticRender( $data, $template_path );
            restore_error_handler();
            return $result;

        } catch( Exception $e ) {
            ob_end_clean();
            restore_error_handler();
            throw new TemplateException(
                    sprintf( 'Unexpected exception while rendering template %s', $template_path ), 500, $e );
        } catch( Throwable $e ) { // for PHP >= 7.0
            ob_end_clean();
            restore_error_handler();
            throw new TemplateException(
                    sprintf( 'Unexpected exception while rendering template %s', $template_path ), 500, $e );
        }
    }


    // prevent apearing of $this in template scope
    private static function staticRender( $data, $template_path ) {
        ob_start();
        include $template_path;
        return ob_get_clean();
    }


}
