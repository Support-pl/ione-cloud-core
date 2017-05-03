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

use TinyApp\Service\RenderingEngine\IRenderingEngine;
use RuntimeException;
use TinyApp\Exception\TemplateException;


/**
 * Rendering engine can be used to merge several ones in order to call
 * next one if previous one fails to render a template.
 */
class MergedRenderingEngine implements IRenderingEngine {

    /** @var IRenderingEngine[] $engines rendering engines */
    private $engines;

    /** @var $on_exception_callback null|callable template exception handler */
    private $on_exception_callback;


    /**
     * Compose several rendering engines into merged one.
     *
     * Engines will be invoked in the sequence they appear in the provided array.
     * Next engine will be invoked if previous one had thrown a TemplateException.
     *
     * Instances of TemplateException can be handled with optional callback.
     * First argument of a callback is an instance of TemplateException thrown,
     * second one is a name of a template, third one is a data, fourth one
     * is an instance of engine.
     *
     * @param IRenderingEngine[] $engines rendering engines
     * @param callable $on_exception_callback callback to handle subsequent
     * TemplateException instances; may be used for logging (optional)
     * @throws RuntimeException if array of engines is empty or if one
     * of the engines is not an instance of IRenderingEngine
     */
    public function __construct( array $engines, callable $on_exception_callback = null ) {

        if( empty( $engines ) ) {
            throw new RuntimeException( 'Array of rendering engines is empty' );
        }

        array_walk( $engines, function ( $engine, $index ) {
            if( !$engine instanceof IRenderingEngine ) {
                throw new RuntimeException( sprintf( 'Value at index "%s" is not an instance of IRenderingEngine', $index ) );
            }
        } );

        $this->engines = $engines;
        $this->on_exception_callback = $on_exception_callback;
    }


    /**
     *
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::addTemplateDirectories()
     */
    public function addTemplateDirectories( $dirs ) {
        foreach( $this->engines as $engine ) {
            $engine->addTemplateDirectories( $dirs );
        }
        return $this;
    }


    /**
     *
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::removeTemplateDirectories()
     */
    public function removeTemplateDirectories( $dirs ) {
        foreach( $this->engines as $engine ) {
            $engine->removeTemplateDirectories( $dirs );
        }
        return $this;
    }


    /**
     *
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::render()
     */
    public function render( $data, $template ) {
        $ex_last = null;
        foreach( $this->engines as $engine ) {
            try {
                return $engine->render( $data, $template );
            } catch( TemplateException $ex ) {
                $this->callExceptionHandler( $ex, $template, $data, $engine );
                $ex_last = $ex;
            }
        }

        if( !$ex_last ) {
            $ex_last = new TemplateException( 'No rendering engines are set, unable to render a template' );
        }

        throw $ex_last;
    }


    /**
     * Set prefix for all bundled rendering engines.
     *
     * @return this
     */
    public function setTemplatePrefix( $prefix ) {
        foreach( $this->engines as $engine ) {
            $engine->setTemplatePrefix( $prefix );
        }
        return $this;
    }


    /**
     * Set postfix for all bundled rendering engines.
     *
     * @return this
     */
    public function setTemplatePostfix( $postfix ) {
        foreach( $this->engines as $engine ) {
            $engine->setTemplatePostfix( $postfix );
        }
        return $this;
    }


    private function callExceptionHandler( TemplateException $ex, $template, $data, IRenderingEngine $engine ) {
        if( $this->on_exception_callback ) {
            call_user_func( $this->on_exception_callback, $ex, $template, $data, $engine );
        }
    }


    /**
     * {@inheritdoc}
     *
     * Prefix of the very first rendering engine in a bundle will be returned.
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplatePrefix()
     */
    public function getTemplatePrefix() {
        return reset( $this->engines )->getTemplatePrefix();
    }


    /**
     * {@inheritdoc}
     *
     * Postfix of the very first rendering engine in a bundle will be returned.
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplatePostfix()
     */
    public function getTemplatePostfix() {
        return reset( $this->engines )->getTemplatePostfix();
    }


    /**
     * {@inheritdoc}
     *
     * Merged array of directories of all bundled rendering engines will be returned.
     *
     * Array will contain unique values in unspecified order.
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplateDirectories()
     */
    public function getTemplateDirectories() {
        $dirs = [];
        foreach( $this->engines as $engine ) {
            $dirs = array_unique( array_merge( $dirs, array_values( $engine->getTemplateDirectories() ) ) );
        }
        return $dirs;
    }

}
