/*
The MIT License (MIT)
Copyright (c) 2016 Claudio Guidi <guidiclaudio@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

include "file.iol"
include "console.iol"
include "string_utils.iol"
include "metajolie.iol"
include "metaparser.iol"

include "./JesterConfiguratorInterface.iol"
include "services/openapi/public/interfaces/OpenApiDefinitionInterface.iol"

execution{ concurrent }

outputPort OpenApi {
  Interfaces: OpenApiDefinitionInterface
}

constants {
  LOG = false
}


embedded {
  Jolie:
    "services/openapi/openapi_definition.ol" in OpenApi
}

inputPort JesterConfigurator {
  Location: "local"
  Protocol: sodep
  Interfaces: JesterConfiguratorInterface
}

define __analize_given_template {
    /* __given_template */
    undef( __method )
    undef( __template )
    if ( !easyInterface && !(__given_template instanceof void) ) {
        r3 = __given_template
        r3.regex = ","
        split@StringUtils( r3 )( r4 )
        for( _p = 0, _p < #r4.result, _p++ ) {
            trim@StringUtils( r4.result[_p] )( r_result )
            r_result.regex = "method="
            find@StringUtils( r_result )( there_is_method )
            if ( there_is_method == 1) {
                split@StringUtils( r_result )( _params )
                trim@StringUtils( _params.result[1] )( __method )
            } else {
                r_result.regex = "template="
                find@StringUtils( r_result )( there_is_template )
                if ( there_is_template == 1) {
                    split@StringUtils( r_result )( _params )
                    trim@StringUtils( _params.result[1] )( __template )
                }
            }
        }
    } else {
        __method = "post"
    }

}

define __add_cast_data {
  if ( is_defined( current_root_type.int_type ) ) {
      current_render_operation.cast.( current_sbt.name ) = "int"
  } else if ( is_defined( current_root_type.long_type ) ){
      current_render_operation.cast.( current_sbt.name ) = "long"
  } else if ( is_defined( current_root_type.double_type ) ){
      current_render_operation.cast.( current_sbt.name ) = "double"
  } else if ( is_defined( current_root_type.bool_type ) ){
      current_render_operation.cast.( current_sbt.name ) = "bool"
  }

}

define __body {
      easyInterface = false;
      if ( is_defined( request.easyInterface ) ) {
          easyInterface = request.easyInterface
      };
      router_host = request.host;
      service_filename = request.filename;
      service_input_port = request.inputPort;

      with( request_meta ) {
        .filename = service_filename;
        .name.name  = "";
        .name.domain = ""
      };
      getInputPortMetaData@MetaJolie( request_meta )( metadata )
      ;
      
      /* selecting the port and the list of the interfaces to be imported */
      for( i = 0, i < #metadata.input, i++ ) {
          // port selection from metadata
          if ( metadata.input[ i ].name.name == service_input_port ) {
              output_port_index = #render.output_port
              getSurfaceWithoutOutputPort@Parser( metadata.input )( render.output_port[ output_port_index ].surface );
              with( render.output_port[ output_port_index ] ) {
                    .name = service_input_port;
                    .location = metadata.input[ i ].location;
                    .protocol = metadata.input[ i ].protocol
              };

              // for each interface in the port
              for( int_i = 0, int_i < #metadata.input[ i ].interfaces, int_i++ ) {
                  c_interface -> metadata.input[ i ].interfaces[ int_i ]
                  c_interface_name = c_interface.name.name
                  render.output_port[ output_port_index ].interfaces[ int_i ] = c_interface_name;
                  
                  // for each operations in the interfaces
                  for( o = 0, o < #c_interface.operations, o++ ) {
                        oper -> c_interface.operations[ o ]
                        if ( LOG ) { println@Console("Analyzing operation:" + oper.operation_name )() }
                        error_prefix =  "ERROR on port " + service_input_port + ", operation " + oper.operation_name + ":" + "the operation has been declared to be imported as a REST ";
                        
                        // proceed only if a rest template has been defined for that operation
                        if ( is_defined( request.template.( oper.operation_name ) ) ) {
                            __given_template = request.template.( oper.operation_name )
                        } else {
                            __given_template = ""
                        }
                       
                        __analize_given_template
                        if ( LOG ) { println@Console("Operation Template:" + __template )() }

                        
                        if ( is_defined( oper.output ) ) {
                            rr_operation_max = #render.output_port[ output_port_index ].interfaces[ int_i ].rr_operation
                            current_render_operation -> render.output_port[ output_port_index ].interfaces[ int_i ].rr_operation[ rr_operation_max ]
                        } else {
                            ow_operation_max = #render.output_port[ output_port_index ].interfaces[ int_i ].ow_operation
                            current_render_operation -> render.output_port[ output_port_index ].interfaces[ int_i ].ow_operation[ ow_operation_max ]
                        }
                        current_render_operation = oper.operation_name
                        current_render_operation.method = __method

                        /* find request type description */
                        tp_count = 0; tp_found = false;
                        while( !tp_found && tp_count < #c_interface.types ) {
                            if ( c_interface.types[ tp_count ].name.name == oper.input.name ) {
                                tp_found = true
                            } else {
                                tp_count++
                            }
                        }

                        if ( tp_found ) {
                            current_type -> c_interface.types[ tp_count ];
                            if ( !is_defined( current_type.root_type.void_type ) ) {
                                println@Console( error_prefix + "but the root type of the request type is not void" )();
                                throw( DefinitionError )
                            }
                        }
                        

                        if ( !( __template instanceof void ) ) {
                            /* check if the params are contained in the request type */
                            splr =__template;
                            splr.regex = "/|\\?|=|&";
                            split@StringUtils( splr )( splres );
                            undef( par );
                            found_params = false;
                            for( pr = 0, pr < #splres.result, pr++ ) {
                                w = splres.result[ pr ];
                                w.regex = "\\{(.*)\\}";
                                find@StringUtils( w )( params );
                                if ( params == 1 ) {
                                    found_params = true;
                                    par = par + params.group[1] + "," /* string where looking for */
                                }
                            }

                            ;

                            if ( found_params ) {

                                    /* there are parameters in the template */
                                    error_prefix = error_prefix + "with template " + __template + " ";
                                    if ( !tp_found ) {
                                        println@Console( error_prefix +  "but the request type does not declare any field")();
                                        throw( DefinitionError )
                                    } else {
                                            /* if there are parameters in the template the request type must be analyzed */
                                            for( sbt = 0, sbt < #current_type.sub_type, sbt++ ) {

                                                /* casting */
                                                current_sbt -> current_type.sub_type[ sbt ];
                                                current_root_type -> current_sbt.type_inline.root_type;
                                                __add_cast_data
                                            }

                                    }
                            } 
                        } else {
                            __template = "/" + oper.operation_name;

                            /* if it is a GET, extract the path params from the request message */
                            if ( __method == "get" ) {
                                    for( sbt = 0, sbt < #current_type.sub_type, sbt++ ) {
                                    /* casting */
                                    current_sbt -> current_type.sub_type[ sbt ];
                                    current_root_type -> current_sbt.type_inline.root_type;
                                    __add_cast_data;

                                    current_sbt -> current_type.sub_type[ sbt ]
                                    __template = __template + "/{" + current_sbt.name + "}"
                                }
                            } 
                            if ( LOG ) { println@Console( "Template automatically generated:" + __template )() }
                        }
                        current_render_operation.template = "/" + service_input_port + __template
                    }
              }
          }
      }
}

define __config_operation {
    with( response.routes[ __r_counter ] ) {
        .method = __cur_op.method;
        .template = __cur_op.template;
        .operation = __cur_op;
        .outputPort = service_input_port;
        foreach( cast_par : __cast ) {
            .cast.( cast_par ) = __cast.( cast_par )
        }
    }
}



main {

    [ getJesterConfig( request )( response ) {
        __body
        route_counter = 0;
        for( op = 0, op < #render.output_port, op++ ) {
            c_op -> render.output_port[ op ];

            for( int_i = 0, int_i < #c_op.interfaces, int_i++ ) {
                for( opr = 0, opr < #c_op.interfaces[ int_i ].ow_operation, opr++ ) {
                        __op_name= c_op.name;
                        __r_counter = route_counter;
                        __cur_op -> c_op.interfaces[ int_i ].ow_operation[ opr ];
                        __cast -> c_op.interfaces[ int_i ].ow_operation[ opr ].cast;
                        __config_operation;
                        route_counter++
                }
                ;
                for( opr = 0, opr < #c_op.interfaces[ int_i ].rr_operation, opr++ ) {
                        __op_name= c_op.name;
                        __r_counter = route_counter;
                        __cur_op -> c_op.interfaces[ int_i ].rr_operation[ opr ];
                        __cast -> c_op.interfaces[ int_i ].rr_operation[ opr ].cast;
                        __config_operation;
                        route_counter++
                }
            }
        }
    }]

}