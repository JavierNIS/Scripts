#!/bin/bash

##########################################################################################################################
#Script Name	: Making_Makefiles.sh
#Description	: A bash script with minimal dependencies to create a makefile 
#Args			: -P -I -S -IX -SX --single --library --force
#Author			: Javier Niño Sánchez
#Email			: javierni.sanchez@gmail.com
##########################################################################################################################
set -euo pipefail
IFS=$'\n\t'

#Variables related to the state of processing the data.
#CREATED_TARGETS=0
PARAMS_USED=0
declare -a TARGET_FILES=()
declare -A TARGET_SEEN=()
#The associative array will store how many libraries, onefiles and such will be built
#example: HOW_TARGETS_ARE_BUILT["static"] = number_of_static_libraries
declare -A HOW_MANY_TARGETS_ARE_BUILT=()
#This array will indicate the order in which each target is treated, 
#It saves if first the first targets are libraries, onefiles and such will be built
#example: ORDER_IN_WHICH_TO_BUILD[0] = "static", so the first n targets are static libraries 
declare -a ORDER_IN_WHICH_TO_BUILD=()

#Variables and their default values, they can be changed later.
INCLUDE_DIR="include"
SOURCE_DIR="src"
PATH_USED=$(pwd)
COMP="g++"
COMP_FLAGS="-std=c++17 -Wall -g -Ofast"

#ONEFILE_TARGET=0
#MAKING_LIBRARY=0
FORCE_PROJECT_CREATION=0
SRC_EXTENSION="cpp"
INC_EXTENSION="h"

#At first the makefile assumes only binaries will be made
BUILDING_ONLY_BINARIES=1


##########################################################################################################################
#will print out a guide on how to use this script.
guide(){
	printf "Usage:\n\n"
	printf "\t>program <target1> [<target2> <target3> ... <targetn>]\n"
	printf "\t>program <parameter> <target1> [<target2> <target3> ... <targetn>]"
	printf "\t>program <parameter1> [<parameter2> <parameter3> ... <parametern> ] <target1> [<target2> <target3> ... <targetn>]\n\n"
	printf "Parameters:\n\n"
	printf "\t-P | --path <path_to_project>\n"
	printf "Uses an specific relative or absolute path to process the targets. Every target should be within the path, otherwise they will be missed. The default path is \".\"\n"
	printf "Usually, missed targets are those that are not in the specified path or do not exist.\n"
	printf "\n\t-I | --include <include_dir>\n"
	printf "Uses an specific name for the header directory. If not found within the project, it will be created. The default header directory is \"include\"\n"
	printf "It will change the makefile to accomodate the new name of the header directory. Formatting: Don't add any /, just the preferred name of the folder\n"
	printf "\n\t-S | --source <source_dir>\n"
	printf "Uses an specific name for the source directory. If not found within the project, it will be created. The default source directory is \"src\"\n"
	printf "It will change the makefile to accomodate the new name of the source directory. Formatting: Don't add any /, just the preferred name of the folder\n"
	printf "\n\t-IX <include_extension>\n"
	printf "Uses an specific extension for the header files. This allows for the usage of other file extensions like hpp\n"
	printf "Formating: You just need to name the extension, for example: hpp\n"
	printf "\n\t-SX <source_extension>\n"
	printf "Uses an specific extension for the source files. This allows for the usage of other file extensions like: tpp, cc...\n"
	printf "Formating: You just need to name the extension\n"
	printf "\n\t--static <number_of_static_libraries>\n"
	printf "It will prepare the makefile for library making. You can use this option along with --dynamic.\n"
  printf "The remaining targets will be turned into dynamic libraries or binaries (depending on order of parameters, and number of remaining targets)\n"
	printf "\n\t--dynamic <number_of_dynamic_libraries>\n"
	printf "It will prepare the makefile for library making. You can use this option along with --static.\n"
  printf "The remaining targets will be turned into static libraries or binaries (depending on order of parameters, and number of remaining targets)\n"
  printf "\n\t-C | --compiler <compiler>\n"
	printf "Allows you to choose which compiler to use for your project, default is: g++.\n"
  printf "\n\t-CF | --compiler-flags <compiler>\n"
	printf "Allows you to choose what flags to use for your project, default is: -std=c++17 -Wall -g -Ofast.\n"
	printf "It is expected that you write the compiler flags inside \"\".\n"
	printf "\n\t--force\n"
	printf "It will force the creation of the project if it couldn't be found in the given path, if that path doesn't exist then the targets will be missed still\n"
	printf "\nNotes:\n\n"
	printf ">The script doesn't care the order in which you use the parameters. Except for --static and --dynamic"\n 
	printf ">You might use -IS <include_dir> <source_dir> and -ISX <include_extension> <source_extension> instead of -I -S and -IX -SX.\n"
	printf ">The path you use will define were your targets are, in other words, if /this/is/your/path/\n"
	printf "then, your targets will be interpreted as: /this/is/your/path/project/source_dir/target1 /this/is/your/path/project/source_dir/target2 ... /this/is/your/path/project/source_dir/targetn.\n"
	printf "Being project the directory where you will work. And tarjet all the source files that contain the main function\n"
	exit 0;
}
##########################################################################################################################


##########################################################################################################################
#Helps parse and verify the parameters, if any have been passed. 0 equals true, 1 equals false. FORMAT_IS_CORRECT can be greater than one.
verify_parameters(){
	#Local variables used to catch parameters.
	local FINISHED=0
	local FORMAT_IS_CORRECT=0
	local REPEATED_PARAMS=0

	#Let's see if the user wants some help, if thats the case, the program will show a guide.
	if [ "$#" == 0 ]
	then
		FORMAT_IS_CORRECT=2
	elif [ "$1" == "--help" ] || [ "$1" == "-help" ] || [ "$1" == "-h" ]
	then
		guide
	fi

	#Here starts the loop.
	while [ $FORMAT_IS_CORRECT -eq 0 ] && [ "$FINISHED" -eq 0 ]
	do
    #the user didn't specify any target but there are 0 parameters to parse left
    if [ "$#" -eq 0 ]; then FINISHED=1; break; fi

		#Saves the parameter before it is processed, that way, if the parameter is duplicated, then the script stops.
		for param in "${USED_PARAMS[@]}"; do
      if [ "$param" == "$1" ]; then
        REPEATED_PARAMS=1
        FORMAT_IS_CORRECT=1
      fi
    	done
		USED_PARAMS+=("$1")
		#If it is not a duplicate, then it will check what paremeter it is.

		#Let's explain a bit more the structure of every case:
		#>Every parameter will be checked as if they were the last one, that means that if the parameter
		#accepts a name (like -I, -S --path...) then, there has to be at least 3 parameters:
		#	>The first parameter for -I, -S, --path...
		#	>The second parameter that is for the name given (like: header, source, /bin...)
		#	>The third argument, that should be a potential target (in case that the loop is checking the last parameter given)

		#There are some variations, for example, --single and --library only need to check if there are at least two more arguments:
		#	>The first parameter, themselves (--single, --library)
		#	>The second argument, that should be a potential target

		#In case of having parameters like -IS, there should be at least 4 parameters more:
		#	>The first parameter for -IS and -ISX
		#	>The second and third parameter for the given names (like: header source, tpp hpp)
		#	>The forth argument, that should be a potential target

		#After the case, if the format is correct, the list of arguments will be shifted accordingly and the number of used arguments will be increased.
		#As a note, FORMAT_IS_CORRECT will take the value 3 if there are no targets.
		case "$1" in
		-P|--path)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ ! -d "$2" ]
			then
				printf "Error. The given path doesn't exist.\n"
				FORMAT_IS_CORRECT=1
			else
				PATH_USED="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-S|--source)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				SOURCE_DIR="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-I|--include)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INCLUDE_DIR="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-IS)
			if [ "$#" -lt 3 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ] || [ "$3" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INCLUDE_DIR="$2"
				SOURCE_DIR="$3"
				shift 3
				PARAMS_USED=$((PARAMS_USED+3))
			fi
		;;
		-IX)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INC_EXTENSION="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-SX)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				SRC_EXTENSION="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-ISX)
			if [ "$#" -lt 3 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ] || [ "$3" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INC_EXTENSION="$2"
				SRC_EXTENSION="$3"
				shift 3
				PARAMS_USED=$((PARAMS_USED+3))
			fi
		;;
		--dynamic)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else 
        ORDER_IN_WHICH_TO_BUILD+="dynamic"
        HOW_TARGETS_ARE_BUILD["dynamic"]=$2
				shift 2 
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		--static)
			if [ "$#" -lt 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else	
        ORDER_IN_WHICH_TO_BUILD+="static"
        HOW_TARGETS_ARE_BUILD["static"]=$2
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
    -C|--compiler)
      if [ "$#" -lt 2 ]; then
        FORMAT_IS_CORRECT=2
      elif [ "$2" == -* ]; then 
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else 
        COMP="$2"
        shift 2
        PARAMS_USED=$((PARAMS_USED+2))
      fi
    ;;
    -CF|--compiler-flags)
      if [ "$#" -lt 2 ]; then
        FORMAT_IS_CORRECT=2
      elif [ "$2" == -* ]; then 
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else 
        COMP_FLAGS="$2"
        shift 2
        PARAMS_USED=$((PARAMS_USED+2))
      fi
    ;;
		--force)
			if [ "$#" -lt 1 ]
			then
				FORMAT_IS_CORRECT=2
			else
				FORCE_PROJECT_CREATION=1
				shift
				PARAMS_USED=$((PARAMS_USED+1))
			fi
		;;
		-*|--*)
			printf "The given parameter $1 doesn't exist\n"
			FORMAT_IS_CORRECT=1
		;;
		*)
			FINISHED=1
		;;
		esac
	done
	#Catches the error format and if any of the parameters have been repeated.
	if [ $REPEATED_PARAMS -eq 1 ]
	then
		printf "You have repeating parameters.\n"
	fi
	if [ $FORMAT_IS_CORRECT -eq 2 ]
	then
		printf "There are no targets to process.\n"
	fi
	if [ $FORMAT_IS_CORRECT -ge 1 ]
	then
		printf "Aborting...\n"
		printf "The format seems to be incorrect, for more help on the use -h, --help or -help\n"
		printf "Example of usage: ./NameOfTheProgram --force -P /example/path -S source mytarget1 mytarget2\n\n"
		exit 1;
	fi
  ORDER_IN_WHICH_TO_BUILD+="binary"
}
##########################################################################################################################

#BUG: Will say that a file has a main if a string has main()
file_has_main(){
  awk '
    BEGIN { in_block = 0; found = 0 }
    {
      line = $0
      # process until there is nothing to change
      while (1) {
        if (in_block) {
          # look for end of comment
          e = index(line, "*/")
          if (e == 0) { line = ""; break }     # entire line inside block comment
          line = substr(line, e+2)             # remove up to and including "*/"
          in_block = 0
          next
        } else {
          s = index(line, "/*")
          t = index(line, "//")
          if (s == 0 && t == 0) break          # nothing to strip on this line
          if (t != 0 && (s == 0 || t < s)) {   # line comment earlier than block start
            line = substr(line, 1, t-1)
            break
          }
          if (s != 0) {
            # remove block from s onward; check if the closing */ is on same line
            prefix = (s>1) ? substr(line, 1, s-1) : ""
            rest = substr(line, s+2)
            e = index(rest, "*/")
            if (e == 0) {
              line = prefix
              in_block = 1
              break
            } else {
              # remove the block and continue scanning the remainder
              line = prefix substr(rest, e+2)
            }
          }
        }
      }
      # after comment-stripping, test for main with a conservative boundary:
      # (^|[^[:alnum:]_])main[[:space:]]*(
      if (line ~ /(^|[^[:alnum:]_])main[[:space:]]*\(/) {
        found = 1
        exit
      } 
  }
  END {
    exit (!found)
  }
  ' "$1" 

}

##########################################################################################################################
find_sources_headers(){
  if [ ! -d "$SOURCE_DIR" ]; then
    printf "[WARN] Source directory $PROJECT_DIR$SOURCE_DIR does not exist.\n"
    exit 1
  fi

  mapfile -d '' -t SOURCE_FILES < <(find "./$SOURCE_DIR" -type f -name "*.${SRC_EXTENSION}" -print0)
  if [ ${#SOURCE_FILES[@]} -eq 0 ]; then
    printf "[WARN] No source files found under %s with extension %s\n" "$SOURCE_DIR" "$SRC_EXTENSION"
  fi

  mapfile -d '' -t HEADER_FILES < <(find "./$INCLUDE_DIR" -type f -name "*.${INC_EXTENSION}" -print0)
  if [ ${#HEADER_FILES[@]} -eq 0 ]; then
    printf "[WARN] No header files found under %s with extension %s\n" "$INCLUDE_DIR" "$INC_EXTENSION"
  fi
  
  for i in "${!SOURCE_FILES[@]}"; do 
    SOURCE_FILES[$i]=$(basename "${SOURCE_FILES[$i]}")
  done
  for i in "${!HEADER_FILES[@]}"; do 
    HEADER_FILES[$i]=$(basename "${HEADER_FILES[$i]}")
  done
}

##########################################################################################################################

find_source_by_name(){
  if [ "$1" == "*.$SRC_EXTENSION" ]; then
    for file in "${SOURCE_FILES[@]}"; do 
      if [ "$file" == "$1" ]; then
        printf "$file\n"
        return 0
      fi
    done
  else 
    for file in "${SOURCE_FILES[@]}"; do 
      if [ "${file%.*}" == "$1" ]; then
        printf "$file\n"
        return 0
      fi 
    done
  fi
  return 1
}

##########################################################################################################################

add_proposed_targets(){
  for target in "$@"; do
    if src_file="$(find_source_by_name $target)"; then
      if file_has_main "./$SOURCE_DIR/$src_file"; then
        if [ -z "${TARGET_SEEN[$src_file]:-}" ]; then
          TARGET_FILES+=("$src_file")
          TARGET_SEEN["$src_file"]=1
        fi
      else 
        printf "[ERR] specified target $target (file: $src_file) does not contain an active main() definition\n"
      fi
    else
      printf "[ERR] specified target $target not found amoung source files\n"
    fi
  done
}

##########################################################################################################################

find_targets_in_source(){
  for source in "${SOURCE_FILES[@]}"; do
      if file_has_main "./$SOURCE_DIR/$source"; then
        if [ -z "${TARGET_SEEN[$source]:-}" ]; then
          TARGET_FILES+=("$source")
          TARGET_SEEN["$source"]=1
        fi
      fi
  done
}

##########################################################################################################################
#The function that makes de the Makefile
# TODO: increase functionality, create debug and production build
# TODO: Add actual rules for libraries
populate_makefile(){
	#Header of the makefile
	printf "#@Brief: Autogenerated makefile\n" > $MAKE_NAME
  printf "#@Date: %s\n\n" "$(date +%d/%m/%Y)" >> $MAKE_NAME

	#Prints the flags for g++ and the working directories
	printf "#Options and directories\n" >> $MAKE_NAME
	printf "CXX = $COMP\n" >> $MAKE_NAME
	printf "CXXFLAGS = $COMP_FLAGS\n" >> $MAKE_NAME

  #printf "PROJECT_DIR = %s\n" "$PROJECT_DIR" >> $MAKE_NAME
  printf "SRC_DIR = %s\n" "./$SOURCE_DIR" >> $MAKE_NAME
  printf "HEADER_DIR = %s\n" "./$INCLUDE_DIR" >> $MAKE_NAME
	printf "OBJ_DIR = ./objects\n" >> $MAKE_NAME
	printf "BIN_DIR = ./bin\n\n" >> $MAKE_NAME

	#If you are making an executable, then it will print out the target only
	#If you are making a library, then it will have the .ar or the .so extension
	printf "#Globals\n" >> $MAKE_NAME
  printf 'NAMES=' >> $MAKE_NAME

  local names=()
  local processed_targets=0
  local index_current_type=0
  local current_type="${ORDER_IN_WHICH_TO_BUILD[$index_current_type]}"
  local remaining_current=${HOW_MANY_TARGETS_ARE_BUILT[$current_type]:-0}
  for i in "${!TARGET_FILES[@]}"; do 
    while [ "$i" -ge $(( processed_targets + remaining_current )) ]; do  
      processed_targets=$(( processed_targets + remaining_targets )) #adjusts the base
      index_current_type=$(( index_current_type + 1 ))
      current_type="${ORDER_IN_WHICH_TO_BUILD[$index_current_type]}"
      remaining_current=${HOW_MANY_TARGETS_ARE_BUILT[$current_type]:-0}
    done 
    
    local target_base="${TARGET_FILES[$i]%.*}"
    local suf=""
    case "$current_type" in 
      static) suf=".ar" ;;
      dynamic) suf=".so" ;;
      binary) suf="" ;;
      *) suf="" ;;
    esac
    names+=("${target_base}${suf}")

  done
  for name in "${names[@]}"; do 
    printf ' %s' "$name" >> $MAKE_NAME
  done
  printf "\n" >> $MAKE_NAME
  
  #Get general sources
  printf "SOURCES_NOT_TARGET :=" >> $MAKE_NAME
  for src in "${SOURCE_FILES_NOT_TARGET[@]}"; do
    printf " %s" "$src" >> $MAKE_NAME
  done
  printf "\n" >> $MAKE_NAME
  
  #Get the main files
  printf "SOURCES_TARGET :=" >> $MAKE_NAME
  for src in "${TARGET_FILES[@]}"; do 
    printf " %s" "$src" >> $MAKE_NAME
  done
  printf "\n" >> $MAKE_NAME

  #Get the headers
  printf "HEADERS :=" >> $MAKE_NAME
  for src in "${HEADER_FILES[@]}"; do 
    printf " %s" "$src" >> $MAKE_NAME
  done
  printf "\n" >> $MAKE_NAME
  
  printf 'SOURCES_NT_PATH := $(addprefix $(SRC_DIR)/,$(SOURCES_NOT_TARGET))\n' >> $MAKE_NAME
  printf 'SOURCES_TARGET_PATH := $(addprefix $(SRC_DIR)/,$(SOURCES_TARGET))\n' >> $MAKE_NAME
  printf 'HEADERS_PATH := $(addprefix $(HEADER_DIR)/,$(HEADERS))\n' >> $MAKE_NAME
  printf 'NAMES_PATH := $(addprefix $(BIN_DIR)/,$(NAMES))\n' >> $MAKE_NAME

  printf 'SOURCES_NT_OBJ := $(patsubst $(SRC_DIR)/%s, $(OBJ_DIR)/%%.o, $(SOURCES_NT_PATH))\n' "%.$SRC_EXTENSION" >> $MAKE_NAME
  printf 'SOURCES_TARGET_OBJ := $(patsubst $(SRC_DIR)/%s, $(OBJ_DIR)/%%.o, $(SOURCES_TARGET_PATH))\n\n' "%.$SRC_EXTENSION" >> $MAKE_NAME

  printf 'all: dirs $(NAMES_PATH)\n' >> $MAKE_NAME
	printf "#Make the directory for the objects\n" >> $MAKE_NAME
	printf "dirs:\n" >> $MAKE_NAME
  printf '\t@mkdir -p $(OBJ_DIR) $(BIN_DIR)\n\n' >> $MAKE_NAME

  printf "#Link it all together\n" >> $MAKE_NAME
  printf '$(BIN_DIR)/%%: $(OBJ_DIR)/%%.o $(SOURCES_NT_OBJ)\n' >> $MAKE_NAME
  printf '\t$(CXX) $(CXXFLAGS) -o $@ $^\n\n' >> $MAKE_NAME

  printf "#Compile source code into objects\n" >> $MAKE_NAME
  printf '$(OBJ_DIR)/%%.o: $(SRC_DIR)/%s $(HEADERS_PATH)\n' "%.$SRC_EXTENSION" >> $MAKE_NAME
  printf '\t$(CXX) -c $(CXXFLAGS) -I$(HEADER_DIR) -o $@ $< \n\n' >> $MAKE_NAME

	#auxiliar function
	printf "#Clean everything\n" >> $MAKE_NAME
	printf "clean:\n" >> $MAKE_NAME
  printf '\t@rm -rf $(OBJ_DIR) $(BIN_DIR)\n\n' >> $MAKE_NAME
	printf ".PHONY: all clean dirs\n" >> $MAKE_NAME
}
##########################################################################################################################


##########################################################################################################################
create_project_directory(){
  if [ "$PATH_USED" == "." ]; then
    PATH_USED=$(pwd)
  fi 

  readonly PROJECT_DIR="$PATH_USED"

  if [ -d "$PROJECT_DIR" ]; then 
    return 0
  elif [ $FORCE_PROJECT_CREATION -eq 1 ]; then
    mkdir "$PROJECT_DIR"
    printf "[INFO] Created the project directory: $PROJECT_DIR\n"
  else 
    printf "[ERR] Couldn't find the project: $PROJECT_DIR\n"
    exit 1
  fi
}
##########################################################################################################################


##########################################################################################################################
create_or_update_makefile(){
  MAKE_NAME="./Makefile"
  if [ -f "$MAKE_NAME" ];then
    printf "[INFO] Updating makefile $MAKE_NAME...\n"
  else 
    if touch "$MAKE_NAME"; then
      printf "[INFO] Makefile created successfully\n"
    else 
      printf "[ERR] Makefile couldn't be created\n"
      exit 1
    fi 
  fi
}
##########################################################################################################################


##########################################################################################################################
create_header_and_source_directories(){
  if [ ! -d "./$SOURCE_DIR" ]
  then
    mkdir "./$SOURCE_DIR"
    printf "Source directory created\n"
  fi
  if [ ! -d "./$INCLUDE_DIR" ] #&& [ $ONEFILE_TARGET -eq 0 ]
  then
    mkdir "./$INCLUDE_DIR"
    printf "Include directory created\n"
  fi
}
##########################################################################################################################

isolate_non_target_sources(){
  SOURCE_FILES_NOT_TARGET=()
  for src in ${SOURCE_FILES[@]}; do 
    if [ -z ${TARGET_SEEN["$src"]:-} ]; then
      SOURCE_FILES_NOT_TARGET+=("$src")
    fi
  done
}

##########################################################################################################################

get_number_of_binaries(){
  local num_targets=${#TARGET_FILES[@]}
  local num_static=${HOW_MANY_TARGETS_ARE_BUILT["static"]:-0}
  local num_dynamic=${HOW_MANY_TARGETS_ARE_BUILT["dynamic"]:-0}
  HOW_MANY_TARGETS_ARE_BUILT["binary"]=$(( num_targets - num_static - num_dynamic ))
}

##########################################################################################################################
# TODO: Add dependency checking for builds
verify_parameters $@
#shift the parameters according to its use in the verify_parameters function
shift "$PARAMS_USED"

create_project_directory

if [ -d "$PROJECT_DIR" ];then
  cd "$PROJECT_DIR"
  create_or_update_makefile
  create_header_and_source_directories
  find_sources_headers
  
  #did the user add target files? if not, then try to find files with the
  #main function
  if [ $# -eq 0 ]; then
    find_targets_in_source
  else 
    add_proposed_targets $@
  fi
  get_number_of_binaries

  isolate_non_target_sources
  populate_makefile
fi
#c'est finni!
exit 0
