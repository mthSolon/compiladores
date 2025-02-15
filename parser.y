%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdbool.h>
    
    extern int yylex();
    extern int yyparse();
    extern FILE *yyin;
    void yyerror(const char *s);
    int semantic_error = 0;
    
    FILE *output;
    int pwm_channel_counter = 0;
    bool has_wifi = false;
    bool has_serial = false;
%}

    // Tabela de símbolos
    %code requires {
        typedef enum {
            TYPE_INTEGER,
            TYPE_BOOLEAN,
            TYPE_STRING,
            TYPE_UNKNOWN
        } VarType;

        typedef enum {
            PIN_UNDEFINED,
            PIN_INPUT,
            PIN_OUTPUT,
            PIN_PWM
        } PinConfig;
    }

    %union {
        int num;
        char *str;
        struct {
            char *code;
            VarType type;
        } expr;
    }

%{
    typedef struct {
        char *name;
        VarType type;
        PinConfig pin_config;
        bool is_declared;
        int declared_line;
    } Symbol;
    
    #define MAX_SYMBOLS 100
    Symbol symbol_table[MAX_SYMBOLS];
    int symbol_count = 0;
    
    // Funções da tabela
    int find_symbol(const char *name) {
        for (int i = 0; i < symbol_count; i++) {
            if (strcmp(symbol_table[i].name, name) == 0) {
                return i;
            }
        }
        return -1;
    }
    
    void add_symbol(const char *name, VarType type) {
        int idx = find_symbol(name);
        if (idx != -1) {
            fprintf(stderr, "Erro Semântico: Variável '%s' já foi declarada anteriormente.\n", name);
            semantic_error = 1;
            return;
        }
        
        if (symbol_count >= MAX_SYMBOLS) {
            fprintf(stderr, "Erro: Número máximo de símbolos excedido.\n");
            exit(1);
        }
        
        symbol_table[symbol_count].name = strdup(name);
        symbol_table[symbol_count].type = type;
        symbol_table[symbol_count].pin_config = PIN_UNDEFINED;
        symbol_table[symbol_count].is_declared = true;
        symbol_count++;
    }
    
    VarType get_var_type(const char *name) {
        int idx = find_symbol(name);
        if (idx == -1) {
            return TYPE_UNKNOWN;
        }
        return symbol_table[idx].type;
    }
    
    bool check_var_declared(const char *name) {
        int idx = find_symbol(name);
        if (idx == -1) {
            fprintf(stderr, "Erro Semântico: Variável '%s' não foi declarada antes do uso.\n", name);
            semantic_error = 1;
            return false;
        }
        return true;
    }
    
    void set_pin_config(const char *name, PinConfig config) {
        int idx = find_symbol(name);
        if (idx != -1) {
            symbol_table[idx].pin_config = config;
        }
    }
    
    PinConfig get_pin_config(const char *name) {
        int idx = find_symbol(name);
        if (idx == -1) {
            return PIN_UNDEFINED;
        }
        return symbol_table[idx].pin_config;
    }
    
    // Verificação de tipagem das expressões
    VarType check_binary_op(VarType left, VarType right, char *op) {
        if (left == TYPE_UNKNOWN || right == TYPE_UNKNOWN)
            return TYPE_UNKNOWN;
            
        if (left == TYPE_STRING || right == TYPE_STRING) {
            if (strcmp(op, "+") == 0) // String concatenation
                return TYPE_STRING;
            fprintf(stderr, "Erro Semântico: Operação '%s' não pode ser aplicada a strings.\n", op);
            semantic_error = 1;
            return TYPE_UNKNOWN;
        }
        
        // Tratar booleano e inteiro como compatíveis
        return TYPE_INTEGER;
    }
%}

    /* Tokens */
    %token CONFIG FIM REPITA
    %token VAR INTEIRO BOOLEANO TEXTO
    %token CONFIGURAR COMO SAIDA ENTRADA
    %token CONFIGURAR_PWM COM FREQUENCIA RESOLUCAO
    %token AJUSTAR_PWM VALOR
    %token LIGAR DESLIGAR
    %token LER_DIGITAL LER_ANALOGICO
    %token CONECTAR_WIFI ENVIAR_HTTP
    %token CONFIGURAR_SERIAL ESCREVER_SERIAL LER_SERIAL
    %token SE ENTAO SENAO ENQUANTO
    %token ESPERAR
    %token IGUAL DIFERENTE MENOR MAIOR MENOR_IGUAL MAIOR_IGUAL
    %token ATRIBUICAO MAIS MENOS VEZES DIVIDIDO
    %token PONTO_VIRGULA DOIS_PONTOS VIRGULA
    %token <num> NUMERO
    %token <str> STRING IDENTIFICADOR
    
    /* Precedência de operação e associação */
    %left IGUAL DIFERENTE
    %left MENOR MAIOR MENOR_IGUAL MAIOR_IGUAL
    %left MAIS MENOS
    %left VEZES DIVIDIDO
    
    %type <str> comandos
    %type <str> comando
    %type <str> lista_ids
    %type <expr> expressao
    
    %%
    
    programa:
        declaracoes config_secao repita_secao
        ;
    
    declaracoes:
        /* empty */
        | declaracoes declaracao
        ;
    
    declaracao:
        VAR INTEIRO DOIS_PONTOS lista_ids PONTO_VIRGULA {
            char *id = strdup($4);
            char *token = strtok(id, ",");
            while (token) {
                // Remove leading/trailing spaces
                while (*token == ' ') token++;
                char *end = token + strlen(token) - 1;
                while (end > token && *end == ' ') *end-- = 0;
                
                add_symbol(token, TYPE_INTEGER);
                token = strtok(NULL, ",");
            }
            free(id);
            fprintf(output, "int %s;\n", $4);
        }
        | VAR BOOLEANO DOIS_PONTOS lista_ids PONTO_VIRGULA {
            char *id = strdup($4);
            char *token = strtok(id, ",");
            while (token) {
                // Remove leading/trailing spaces
                while (*token == ' ') token++;
                char *end = token + strlen(token) - 1;
                while (end > token && *end == ' ') *end-- = 0;
                
                add_symbol(token, TYPE_BOOLEAN);
                token = strtok(NULL, ",");
            }
            free(id);
            fprintf(output, "bool %s;\n", $4);
        }
        | VAR TEXTO DOIS_PONTOS lista_ids PONTO_VIRGULA {
            char *id = strdup($4);
            char *token = strtok(id, ",");
            while (token) {
                // Remove leading/trailing spaces
                while (*token == ' ') token++;
                char *end = token + strlen(token) - 1;
                while (end > token && *end == ' ') *end-- = 0;
                
                add_symbol(token, TYPE_STRING);
                token = strtok(NULL, ",");
            }
            free(id);
            fprintf(output, "String %s;\n", $4);
        }
        ;
    
    lista_ids:
        IDENTIFICADOR {
            $$ = $1;
        }
        | lista_ids VIRGULA IDENTIFICADOR {
            char buffer[1024];
            sprintf(buffer, "%s, %s", $1, $3);
            $$ = strdup(buffer);
        }
        ;
    
    config_secao:
        CONFIG comandos FIM {
            fprintf(output, "void setup() {\n");
            fprintf(output, "%s", $2);
            fprintf(output, "}\n\n");
        }
        ;
    
    repita_secao:
        REPITA comandos FIM {
            fprintf(output, "void loop() {\n");
            fprintf(output, "%s", $2);
            fprintf(output, "}\n");
        }
        ;
    
    comandos:
        /* empty */ {
            $$ = strdup("");
        }
        | comandos comando {
            char buffer[4096];
            sprintf(buffer, "%s%s", $1, $2);
            $$ = strdup(buffer);
            free($1);
            free($2);
        }
        ;
    
    comando:
        IDENTIFICADOR ATRIBUICAO expressao PONTO_VIRGULA {
            if (check_var_declared($1)) {
                VarType var_type = get_var_type($1);
                if (var_type != $3.type && !(var_type == TYPE_INTEGER && $3.type == TYPE_BOOLEAN) && 
                    !(var_type == TYPE_BOOLEAN && $3.type == TYPE_INTEGER)) {
                    if (var_type == TYPE_STRING && $3.type != TYPE_STRING) {
                        fprintf(stderr, "Erro Semântico: Tentativa de usar 'texto' para armazenar um valor numérico.\n");
                    }
                    else if (var_type == TYPE_INTEGER && $3.type == TYPE_STRING) {
                        fprintf(stderr, "Erro Semântico: Tentativa de usar 'inteiro' para armazenar um valor texto.\n");
                    }
                    else if (var_type == TYPE_BOOLEAN && $3.type == TYPE_STRING) {
                        fprintf(stderr, "Erro Semântico: Tentativa de usar 'booleano' para armazenar um valor texto.\n");
                    }
                    semantic_error = 1;
                }
            }
            
            char buffer[1024];
            sprintf(buffer, "  %s = %s;\n", $1, $3.code);
            $$ = strdup(buffer);
            free($3.code);
        }
        | CONFIGURAR IDENTIFICADOR COMO SAIDA PONTO_VIRGULA {
            if (check_var_declared($2)) {
                set_pin_config($2, PIN_OUTPUT);
            }
            
            char buffer[1024];
            sprintf(buffer, "  pinMode(%s, OUTPUT);\n", $2);
            $$ = strdup(buffer);
        }
        | CONFIGURAR IDENTIFICADOR COMO ENTRADA PONTO_VIRGULA {
            if (check_var_declared($2)) {
                set_pin_config($2, PIN_INPUT);
            }
            
            char buffer[1024];
            sprintf(buffer, "  pinMode(%s, INPUT);\n", $2);
            $$ = strdup(buffer);
        }
        | CONFIGURAR_PWM IDENTIFICADOR COM FREQUENCIA NUMERO RESOLUCAO NUMERO PONTO_VIRGULA {
            if (check_var_declared($2)) {
                set_pin_config($2, PIN_PWM);
            }
            
            char buffer[1024];
            sprintf(buffer, "  // Configuração do PWM para %s\n", $2);
            sprintf(buffer + strlen(buffer), "  const int pwmChannel%d = %d;\n", pwm_channel_counter, pwm_channel_counter);
            sprintf(buffer + strlen(buffer), "  ledcSetup(pwmChannel%d, %d, %d);\n", pwm_channel_counter, $5, $7);
            sprintf(buffer + strlen(buffer), "  ledcAttachPin(%s, pwmChannel%d);\n", $2, pwm_channel_counter);
            pwm_channel_counter++;
            $$ = strdup(buffer);
        }
        | AJUSTAR_PWM IDENTIFICADOR COM VALOR expressao PONTO_VIRGULA {
            if (check_var_declared($2)) {
                PinConfig pin_config = get_pin_config($2);
                if (pin_config != PIN_PWM) {
                    fprintf(stderr, "Erro Semântico: %s não está configurado como PWM.\n", $2);
                    semantic_error = 1;
                }
                
                if ($5.type != TYPE_INTEGER && $5.type != TYPE_BOOLEAN) {
                    fprintf(stderr, "Erro Semântico: Valor PWM deve ser do tipo inteiro.\n");
                    semantic_error = 1;
                }
            }
            
            
            char buffer[1024];
            sprintf(buffer, "  ledcWrite(pwmChannel%d, %s);\n", pwm_channel_counter - 1, $5.code);
            $$ = strdup(buffer);
            free($5.code);
        }
        | LIGAR IDENTIFICADOR PONTO_VIRGULA {
            if (check_var_declared($2)) {
                PinConfig pin_config = get_pin_config($2);
                if (pin_config != PIN_OUTPUT && pin_config != PIN_PWM) {
                    fprintf(stderr, "Erro Semântico: Tentativa de ligar pino '%s' que não está configurado como saída.\n", $2);
                    semantic_error = 1;
                }
            }
            
            char buffer[1024];
            sprintf(buffer, "  digitalWrite(%s, HIGH);\n", $2);
            $$ = strdup(buffer);
        }
        | DESLIGAR IDENTIFICADOR PONTO_VIRGULA {
            if (check_var_declared($2)) {
                PinConfig pin_config = get_pin_config($2);
                if (pin_config != PIN_OUTPUT && pin_config != PIN_PWM) {
                    fprintf(stderr, "Erro Semântico: Tentativa de desligar pino '%s' que não está configurado como saída.\n", $2);
                    semantic_error = 1;
                }
            }
            
            char buffer[1024];
            sprintf(buffer, "  digitalWrite(%s, LOW);\n", $2);
            $$ = strdup(buffer);
        }
        | IDENTIFICADOR ATRIBUICAO LER_DIGITAL IDENTIFICADOR PONTO_VIRGULA {
            check_var_declared($1);
            
            if (check_var_declared($4)) {
                PinConfig pin_config = get_pin_config($4);
                if (pin_config != PIN_INPUT) {
                    fprintf(stderr, "Erro Semântico: Tentativa de ler pino '%s' que não está configurado como entrada.\n", $4);
                    semantic_error = 1;
                }
            }
            
            VarType var_type = get_var_type($1);
            if (var_type != TYPE_INTEGER && var_type != TYPE_BOOLEAN) {
                fprintf(stderr, "Erro Semântico: Variável '%s' deve ser do tipo inteiro ou booleano para receber leitura digital.\n", $1);
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  %s = digitalRead(%s);\n", $1, $4);
            $$ = strdup(buffer);
        }
        | IDENTIFICADOR ATRIBUICAO LER_ANALOGICO IDENTIFICADOR PONTO_VIRGULA {
            check_var_declared($1);
            
            if (check_var_declared($4)) {
                PinConfig pin_config = get_pin_config($4);
                if (pin_config != PIN_INPUT) {
                    fprintf(stderr, "Erro Semântico: Tentativa de ler pino '%s' que não está configurado como entrada.\n", $4);
                    semantic_error = 1;
                }
            }
            
            VarType var_type = get_var_type($1);
            if (var_type != TYPE_INTEGER) {
                fprintf(stderr, "Erro Semântico: Variável '%s' deve ser do tipo inteiro para receber leitura analógica.\n", $1);
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  %s = analogRead(%s);\n", $1, $4);
            $$ = strdup(buffer);
        }
        | CONECTAR_WIFI IDENTIFICADOR IDENTIFICADOR PONTO_VIRGULA {
            check_var_declared($2);
            check_var_declared($3);
            
            VarType ssid_type = get_var_type($2);
            VarType pass_type = get_var_type($3);
            
            if (ssid_type != TYPE_STRING) {
                fprintf(stderr, "Erro Semântico: SSID deve ser do tipo texto.\n");
                semantic_error = 1;
            }
            
            if (pass_type != TYPE_STRING) {
                fprintf(stderr, "Erro Semântico: Senha WiFi deve ser do tipo texto.\n");
                semantic_error = 1;
            }
            
            has_wifi = true;
            char buffer[1024];
            sprintf(buffer, "  // Conectando WiFi \n");
            sprintf(buffer + strlen(buffer), "  WiFi.begin(%s.c_str(), %s.c_str());\n", $2, $3);
            sprintf(buffer + strlen(buffer), "  while (WiFi.status() != WL_CONNECTED) {\n");
            sprintf(buffer + strlen(buffer), "    delay(500);\n");
            sprintf(buffer + strlen(buffer), "    Serial.println(\"Conectando ao WiFi...\");\n");
            sprintf(buffer + strlen(buffer), "  }\n");
            sprintf(buffer + strlen(buffer), "  Serial.println(\"Conectado ao WiFi!\");\n");
            $$ = strdup(buffer);
        }
        | ENVIAR_HTTP STRING STRING PONTO_VIRGULA {
            if (!has_wifi) {
                fprintf(stderr, "Erro Semântico: Tentativa de enviar HTTP sem configurar WiFi.\n");
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  // Enviar requisição HTTP\n");
            sprintf(buffer + strlen(buffer), "  HTTPClient http;\n");
            sprintf(buffer + strlen(buffer), "  http.begin(%s);\n", $2);
            sprintf(buffer + strlen(buffer), "  http.POST(%s);\n", $3);
            sprintf(buffer + strlen(buffer), "  http.end();\n");
            $$ = strdup(buffer);
        }
        | CONFIGURAR_SERIAL NUMERO PONTO_VIRGULA {
            has_serial = true;
            char buffer[1024];
            sprintf(buffer, "  Serial.begin(%d);\n", $2);
            $$ = strdup(buffer);
        }
        | ESCREVER_SERIAL expressao PONTO_VIRGULA {
            if (!has_serial) {
                fprintf(stderr, "Erro Semântico: Tentativa de escrever na Serial sem configurá-la.\n");
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  Serial.println(%s);\n", $2.code);
            $$ = strdup(buffer);
            free($2.code);
        }
        | IDENTIFICADOR ATRIBUICAO LER_SERIAL PONTO_VIRGULA {
            check_var_declared($1);
            
            if (!has_serial) {
                fprintf(stderr, "Erro Semântico: Tentativa de ler da Serial sem configurá-la.\n");
                semantic_error = 1;
            }
            
            VarType var_type = get_var_type($1);
            if (var_type != TYPE_STRING) {
                fprintf(stderr, "Erro Semântico: Variável '%s' deve ser do tipo texto para receber leitura da Serial.\n", $1);
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  if (Serial.available()) {\n");
            sprintf(buffer + strlen(buffer), "    %s = Serial.readString();\n", $1);
            sprintf(buffer + strlen(buffer), "  }\n");
            $$ = strdup(buffer);
        }
        | SE expressao ENTAO comandos FIM {
            char buffer[1024];
            sprintf(buffer, "  if (%s) {\n%s  }\n", $2.code, $4);
            $$ = strdup(buffer);
            free($2.code);
            free($4);
        }
        | SE expressao ENTAO comandos SENAO comandos FIM {
            char buffer[1024];
            sprintf(buffer, "  if (%s) {\n%s  } else {\n%s  }\n", $2.code, $4, $6);
            $$ = strdup(buffer);
            free($2.code);
            free($4);
            free($6);
        }
        | ENQUANTO comandos FIM {
            char buffer[1024];
            sprintf(buffer, "  while (true) {\n%s  }\n", $2);
            $$ = strdup(buffer);
            free($2);
        }
        | ESPERAR expressao PONTO_VIRGULA {
            if ($2.type != TYPE_INTEGER && $2.type != TYPE_BOOLEAN) {
                fprintf(stderr, "Erro Semântico: Valor para esperar deve ser do tipo inteiro.\n");
                semantic_error = 1;
            }
            
            char buffer[1024];
            sprintf(buffer, "  delay(%s);\n", $2.code);
            $$ = strdup(buffer);
            free($2.code);
        }
        ;
    
    expressao:
        IDENTIFICADOR {
            if (check_var_declared($1)) {
                $$.type = get_var_type($1);
            } else {
                $$.type = TYPE_UNKNOWN;
            }
            $$.code = strdup($1);
        }
        | NUMERO {
            $$.type = TYPE_INTEGER;
            char buffer[32];
            sprintf(buffer, "%d", $1);
            $$.code = strdup(buffer);
        }
        | STRING {
            $$.type = TYPE_STRING;
            $$.code = strdup($1);
        }
        | expressao MAIS expressao {
            $$.type = check_binary_op($1.type, $3.type, "+");
            char buffer[1024];
            sprintf(buffer, "(%s + %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao MENOS expressao {
            $$.type = check_binary_op($1.type, $3.type, "-");
            char buffer[1024];
            sprintf(buffer, "(%s - %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao VEZES expressao {
            $$.type = check_binary_op($1.type, $3.type, "*");
            char buffer[1024];
            sprintf(buffer, "(%s * %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao DIVIDIDO expressao {
            $$.type = check_binary_op($1.type, $3.type, "/");
            char buffer[1024];
            sprintf(buffer, "(%s / %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao IGUAL expressao {
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s == %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao DIFERENTE expressao {
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s != %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao MENOR expressao {
            if (($1.type == TYPE_STRING || $3.type == TYPE_STRING) && 
                !($1.type == TYPE_UNKNOWN || $3.type == TYPE_UNKNOWN)) {
                fprintf(stderr, "Erro Semântico: Operador '<' não pode ser usado com strings.\n");
                semantic_error = 1;
            }
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s < %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao MAIOR expressao {
            if (($1.type == TYPE_STRING || $3.type == TYPE_STRING) && 
                !($1.type == TYPE_UNKNOWN || $3.type == TYPE_UNKNOWN)) {
                fprintf(stderr, "Erro Semântico: Operador '>' não pode ser usado com strings.\n");
                semantic_error = 1;
            }
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s > %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao MENOR_IGUAL expressao {
            if (($1.type == TYPE_STRING || $3.type == TYPE_STRING) && 
                !($1.type == TYPE_UNKNOWN || $3.type == TYPE_UNKNOWN)) {
                fprintf(stderr, "Erro Semântico: Operador '<=' não pode ser usado com strings.\n");
                semantic_error = 1;
            }
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s <= %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        | expressao MAIOR_IGUAL expressao {
            if (($1.type == TYPE_STRING || $3.type == TYPE_STRING) && 
                !($1.type == TYPE_UNKNOWN || $3.type == TYPE_UNKNOWN)) {
                fprintf(stderr, "Erro Semântico: Operador '>=' não pode ser usado com strings.\n");
                semantic_error = 1;
            }
            $$.type = TYPE_BOOLEAN;
            char buffer[1024];
            sprintf(buffer, "(%s >= %s)", $1.code, $3.code);
            $$.code = strdup(buffer);
            free($1.code);
            free($3.code);
        }
        ;
    
    %%
    
    void yyerror(const char *s) {
        fprintf(stderr, "Erro: %s\n", s);
    }
    
    int main(int argc, char **argv) {
        if (argc != 3) {
            fprintf(stderr, "Uso, %s arquivo_entrada arquivo_saida\n", argv[0]);
            return 1;
        }
    
        FILE *input = fopen(argv[1], "r");
        if (!input) {
            fprintf(stderr, "Erro ao abrir o arquivo de entrada %s\n", argv[1]);
            return 1;
        }
    
        output = fopen(argv[2], "w");
        if (!output) {
            fprintf(stderr, "Erro ao abrir o arquivo de saída %s\n", argv[2]);
            fclose(input);
            return 1;
        }
    
        // Write headers
        fprintf(output, "#include <Arduino.h>\n");
        fprintf(output, "#include <WiFi.h>\n");
        fprintf(output, "#include <HTTPClient.h>\n");
        fprintf(output, "\n");
    
        yyin = input;
        yyparse();

        if (semantic_error) {
            fclose(input);
            fclose(output);
            return 1;
        }
    
        fclose(input);
        fclose(output);
        return 0;
    }