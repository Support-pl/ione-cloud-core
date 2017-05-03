<?php


namespace OneCS\Service\WHMCS;

use Illuminate\Database\Capsule\Manager as Capsule;


/**
 * Wrapper for Laravel's database manager.
 */
class DatabaseManager {


    /**
     * Get query builder for given table.
     *
     * @param string $table the table
     * @return \Illuminate\Database\Query\Builder the query builder
     */
    public function getQueryBuilder( $table ) {
        return Capsule::table( $table );
    }


    /**
     * Get databse schema builder.
     *
     * @return \Illuminate\Database\Schema\Builder the schema builder
     */
    public function getSchemaBuilder() {
        return Capsule::schema();
    }


    /**
     * Get database connection.
     *
     * @return \Illuminate\Database\Connection the database connection
     */
    public function getConnection() {
        return Capsule::connection();
    }


}
