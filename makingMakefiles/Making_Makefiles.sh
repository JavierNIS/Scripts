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
MISSED_TARGETS=0
COMPLETED_TARGETS=0
UPDATED_TARGETS=0
PROGRESS=0
PARAMS_USED=0
CREATED_TARGETS=0
#Variables and their default values, they can be changed later.
INCLUDE_DIR="include"
SOURCE_DIR="src"
PATH_USED=$(pwd)
ONEFILE_TARGET=0
MAKING_LIBRARY=0
FORCE_PROJECT_CREATION=0
SRCEXTENSION="cpp"
INCEXTENSION="h"


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
	printf "\n\t--single\n"
	printf "Specifies that there will be a single cpp file. It is assumed that you will only have a source file, so no header directory\n"
	printf "will be made. You can still use the -I, -IX parameters, but it won't have any effects.\n"
	printf "\n\t--library=dynamic|static"
	printf "It will prepare the makefile for library making. You can use this option with any other, even --single.\n"
	printf "Defaults to static library.\n"
	printf "\n\t--force\n"
	printf "It will force the creation of the project if it couldn't be found in the given path, if that path doesn't exist then the targets will be missed still\n"
	printf "\nNotes:\n\n"
	printf ">The script doesn't care the order in which you use the parameters."\n 
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
			if [ "$#" -le 2 ]
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
			if [ "$#" -le 2 ]
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
			if [ "$#" -le 2 ]
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
			if [ "$#" -le 3 ]
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
			if [ "$#" -le 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INCEXTENSION="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-SX)
			if [ "$#" -le 2 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				SRCEXTENSION="$2"
				shift 2
				PARAMS_USED=$((PARAMS_USED+2))
			fi
		;;
		-ISX)
			if [ "$#" -le 3 ]
			then
				FORMAT_IS_CORRECT=2
			elif [ "$2" == -* ] || [ "$3" == -* ]
			then
				printf "Error. You didn't introduce the value of the parameter.\n"
				FORMAT_IS_CORRECT=1
			else
				INCEXTENSION="$2"
				SRCEXTENSION="$3"
				shift 3
				PARAMS_USED=$((PARAMS_USED+3))
			fi
		;;
		--single)
			if [ "$#" -le 1 ]
			then
				FORMAT_IS_CORRECT=2
			else
				ONEFILE_TARGET=1
				shift
				PARAMS_USED=$((PARAMS_USED+1))
			fi
		;;
		--library=dynamic)
			if [ "$#" -le 1 ]
			then
				FORMAT_IS_CORRECT=2
			else	
				MAKING_LIBRARY=1
				LIBRARY_TYPE="dynamic"
				shift 
				PARAMS_USED=$((PARAMS_USED+1))
			fi
		;;
		--library=static)
			if [ "$#" -le 1 ]
			then
				FORMAT_IS_CORRECT=2
			else	
				MAKING_LIBRARY=1
				LIBRARY_TYPE="static"
				shift 
				PARAMS_USED=$((PARAMS_USED+1))
			fi
		;;
		--force)
			if [ "$#" -le 1 ]
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
	NUM_ARGS="$#"
}
##########################################################################################################################


##########################################################################################################################
#The function that makes de the Makefile
# TODO: allow to choose compiler and options
# TODO: increase functionality, create debug and production build
# TODO: Include the option to autodetect source and header files (for makefile updating)
populate_makefile(){
	#Header of the makefile
	printf "#@Brief: Autogenerated makefile\n" > $MAKE_NAME
  printf "#@Date: %s\n\n" "$(date +%d/%m/%Y)" >> $MAKE_NAME

	#Prints the flags for g++ and the working directories
	printf "#Options and directories\n" >> $MAKE_NAME
	printf "CXXFLAGS = -std=c++17 -Wall -g -Ofast\n" >> $MAKE_NAME

  #printf "PROJECT_DIR = %s\n" "$PROJECT_DIR" >> $MAKE_NAME
  printf "SRC_DIR = %s\n" "./$SOURCE_DIR" >> $MAKE_NAME
  printf "HEADER_DIR = %s\n" "./$INCLUDE_DIR" >> $MAKE_NAME
	printf "OBJ_DIR = ./objects/\n\n" >> $MAKE_NAME

	#If you are making an executable, then it will print out the target only
	#If you are making a library, then it will have the .ar or the .so extension
	printf "#Globals\n" >> $MAKE_NAME
	if [ $MAKING_LIBRARY -eq 0 ]; then
		printf "NAME = %s\n" "$targets" >> $MAKE_NAME
	elif [ "$LIBRARY_TYPE" == "static" ]; then
		printf "NAME = %s.ar\n" "$targets" >> $MAKE_NAME
	else
		printf "NAME = %s.so\n" "$targets" >> $MAKE_NAME
	fi
	#Scans the source files and the header files. ONLY ONE EXECUTABLE CAN BE MADE WITH THE BASIC MAKEFILE
  # TODO: look up for source files
  #printf 'SOURCES := $(wildcard $(SRC_DIR)*.'"\$(SRCEXTENSION))" >> $MAKE_NAME
	
	if [ $ONEFILE_TARGET -eq 0 ]; then
    # TODO: look up for header files
    #printf 'HEADERS := $(wildcard $(HEADER_DIR)*.'"\$(INCEXTENSION))" >> $MAKE_NAME
	fi
	
  # TODO: get objects out of the source files
  #printf 'OBJECTS := $(patsubst $(SRC_DIR)%.'"\$(SRCEXTENSION)"', $(OBJ_DIR)%.o, $(SOURCES))' >> $MAKE_NAME
	printf "\n\n" >> $MAKE_NAME
	#Makes the directory where the objects will be stored and makes the executable/library
	printf 'all: obj $(NAME)\n' >> $MAKE_NAME
	printf "#Make the directory for the objects\n" >> $MAKE_NAME
	printf "obj:" >> $MAKE_NAME
	printf '\t@mkdir -p $(OBJ_DIR)\n' >> $MAKE_NAME
		
	if [ $ONEFILE_TARGET -eq 0 ]; then
		if [ $MAKING_LIBRARY -eq 0 ]; then
			printf "#Link it all together" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS) $(HEADERS)' >> $MAKE_NAME
			printf '\tg++ $(CXXFLAGS) $(OBJECTS) -o $(NAME)' >> $MAKE_NAME
		elif [ "$LIBRARY_TYPE" == "static" ]; then
			printf "#Make a static library" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS) $(HEADERS)' >> $MAKE_NAME
			printf '\tar rcs $(NAME).ar $(OBJECTS)' >> $MAKE_NAME
		else
			printf "#Make a dynamic library" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS) $(HEADERS)' >> $MAKE_NAME
			printf '\tg++ -shared -o $(NAME).so $(OBJECTS)' >> $MAKE_NAME
		fi

		printf "#Compile source code into objects" >> $MAKE_NAME
		printf '$(OBJ_DIR)%.o: $(SRC_DIR)%.cpp $(HEADERS)' >> $MAKE_NAME
		printf '\tg++ -c $(CXXFLAGS) -I$(HEADER_DIR) -o $@ $<' >> $MAKE_NAME
	else
		if [ $MAKING_LIBRARY -eq 0 ]; then
			printf "#Link the single file" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS)' >> $MAKE_NAME
			printf '\tg++ $(CXXFLAGS) $(OBJECTS) -o $(NAME)' >> $MAKE_NAME
		elif [ "$LIBRARY_TYPE" == "static" ]; then
			printf "#Make a static library" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS)' >> $MAKE_NAME
			printf '\tar rcs $(NAME).ar $(OBJECTS)' >> $MAKE_NAME
		else
			printf "#Make a dynamic library" >> $MAKE_NAME
			printf '$(NAME): $(OBJECTS)' >> $MAKE_NAME
			printf '\tg++ -shared -o $(NAME).so $(OBJECTS)' >> $MAKE_NAME
		fi
		printf "#Compile the single file into object" >> $MAKE_NAME
		printf '$(OBJ_DIR)%.o: $(SRC_DIR)%.'"$SRCEXTENSION" >> $MAKE_NAME
		printf '\tg++ -c $(CXXFLAGS) -o $@ $<' >> $MAKE_NAME
	fi
	#auxiliar function
	printf "#Clean everything" >> $MAKE_NAME
	printf "clean:" >> $MAKE_NAME
	printf '\t@rm -rf $(OBJ_DIR) $(NAME)' >> $MAKE_NAME
	printf ".PHONY: all clean" >> $MAKE_NAME
}
##########################################################################################################################


##########################################################################################################################
create_project_directory(){
  if [ "$PATH_USED" == "." ]; then
    PATH_USED=$(pwd)
  fi 

  readonly PROJECT_DIR="$PATH_USED"

  #if the path above exists, then it will starts making the makefile, otherwise, it will be marked as missed if the parameter --force was not specified
  if [ ! -d "$PROJECT_DIR" ] && [ $FORCE_PROJECT_CREATION -eq 1 ]
  then
    mkdir "$PROJECT_DIR"
    #CREATED_TARGETS=$((CREATED_TARGETS+1))
    printf "Created the project: $PROJECT_DIR\n"
  fi
}
##########################################################################################################################


##########################################################################################################################
create_makefile(){
  MAKE_NAME="$PROJECT_DIR/Makefile"
  if [ -f "$MAKE_NAME" ];then
    printf "Updating makefile $MAKE_NAME...\n"
  else 
    touch $MAKE_NAME
    if [ $? -eq 0 ]; then
      printf "Makefile created successfully\n"
    else 
      printf "Makefile couldn't be created\n"
    fi 
  fi
}
##########################################################################################################################


##########################################################################################################################
create_header_and_source_directories(){
  if [ ! -d "$PROJECT_DIR/$SOURCE_DIR" ]
  then
    mkdir "$PROJECT_DIR/$SOURCE_DIR"
    printf "Source directory created\n"
  fi
  if [ ! -d "$PROJECT_DIR/$INCLUDE_DIR" ] && [ $ONEFILE_TARGET -eq 0 ]
  then
    mkdir "$PROJECT_DIR/$INCLUDE_DIR"
    printf "Include directory created\n"
  fi
}
##########################################################################################################################

# TODO: Add dependency checking for builds
verify_parameters $@
#shift the parameters according to its use in the verify_parameters function
shift "$PARAMS_USED"

create_project_directory

if [ -d "$PROJECT_DIR" ];then
  create_makefile
  create_header_and_source_directories
  populate_makefile
fi
#c'est finni!
exit 0
