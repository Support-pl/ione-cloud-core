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

use TinyApp\Exception\TemplateNotFoundException;


/**
 * Superclass for rendering engines.
 */
abstract class AbstractRenderingEngine implements IRenderingEngine {


    /** @var array $dirs array of directories to look for templates in */
    protected $dirs = [];

    /** @var string $prefix prefix of template filenames */
    protected $prefix = '';

    /** @var string $postfix postfix of template filenames */
    protected $postfix = '';


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::render()
     */
    public function render( $data, $template ) {

        $path = $this->findTemplate( $template );

        if( null === $path ) {
            throw new TemplateNotFoundException( sprintf( 'Template %s not found', $template ) );
        }

        return $this->doRender( $data, $path );
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::addTemplateDirectories()
     */
    public function addTemplateDirectories( $dirs ) {
        if( is_array( $dirs ) ) {
            $this->dirs = self::toArrayOfUniqueStrings( array_merge( $this->dirs, $dirs ) );
        } else {
            $dir = strval( $dirs );
            if( !in_array( $dir, $this->dirs ) ) {
                $this->dirs[] = $dir;
            }
        }
        return $this;
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::removeTemplateDirectories()
     */
    public function removeTemplateDirectories( $dirs ) {
        $this->dirs = array_diff( $this->dirs, is_array( $dirs )
                ? self::toArrayOfUniqueStrings( $dirs )
                : [ strval( $dirs ) ] );
        return $this;
    }


    /**
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplateDirectories()
     */
    public function getTemplateDirectories() {
        return $this->dirs;
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::setTemplatePrefix()
     */
    public function setTemplatePrefix( $prefix ) {
        $this->prefix = strval( $prefix );
        return $this;
    }


    /**
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplatePrefix()
     */
    public function getTemplatePrefix() {
        return $this->prefix;
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::setTemplatePostfix()
     */
    public function setTemplatePostfix( $postfix ) {
        $this->postfix = strval( $postfix );
        return $this;
    }


    /**
     * {@inheritdoc}
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::getTemplatePostfix()
     */
    public function getTemplatePostfix() {
        return $this->postfix;
    }


    /**
     * Find a template in the directories.
     *
     * @param string $template name of the template
     * @return string|null path to the file of the template, or null if file not found
     */
    protected function findTemplate( $template ) {

        foreach( $this->dirs as $dir ) {

            $path = $dir
                .DIRECTORY_SEPARATOR
                .$this->prefix
                .$template
                .$this->postfix;

            if( is_file( $path ) && is_readable( $path ) ) {
                return $path;
            }
        }

        return null;
    }


    private static function toArrayOfUniqueStrings( array $array ) {
        return array_unique( array_map( 'strval', array_values( $array ) ) );
    }


    /**
     * Render given template using given data.
     *
     * @param mixed $data the data
     * @param mixed $templatepath the path to the template
     * @return string rendered template as a string
     * @throws TemplateException in case of an error
     */
    protected abstract function doRender( $data, $template_path );


}
