#!/bin/bash

##########################################################################################################################
#Script Name	: Making_Makefiles.sh
#Description	: Aids in the creation of a basic Makefile for different purposes.
#Args			: -P -I -S -IX -SX --single --library --force
#Author			: Javier Niño Sánchez
#Email			: javierni.sanchez@gmail.com
##########################################################################################################################
#Variables related to the state of processing the data.
MISSED=0
COMPLETED=0
UPDATED=0
PROGRESS=0
USED=0
CREATED=0
#Variables and their default values, they can be changed later.
INCLUDE="include"
SOURCE="src"
PATH_USED=$(pwd)
ONEFILE=0
LIBRARY=0
FORCE=0
SRCEXTENSION="cpp"
INCEXTENSION="h"
#Used for verification purposes only. It was never used.
declare -a USED_PARAMS

#will print out a guide on how to use this script.
guide(){
	echo -e "Usage:\n"
	echo -e "\t>program <target1> [<target2> <target3> ... <targetn>]"
	echo -e "\t>program <parameter> <target1> [<target2> <target3> ... <targetn>]"
	echo -e "\t>program <parameter1> [<parameter2> <parameter3> ... <parametern> ] <target1> [<target2> <target3> ... <targetn>]\n"
	echo "Parameters:\n"
	echo -e "\t-P | --path <path_to_dir>"
	echo "Uses an specific relative or absolute path to process the targets. Every target should be within the path, otherwise they will be missed. The default path is \".\""
	echo "Usually, missed targets are those that are not in the specified path or do not exist."
	echo -e "\n\t-I | --include <include_dir>"
	echo "Uses an specific name for the header directory. If not found within the target(s), it will be created. The default header directory is \"include\""
	echo "It will change the makefile to accomodate the new name of the header directory. Formatting: Don't add any /, just the preferred name of the folder"
	echo -e "\n\t-S | --source <source_dir>"
	echo "Uses an specific name for the source directory. If not found within the target(s), it will be created. The default source directory is \"src\""
	echo "It will change the makefile to accomodate the new name of the source directory. Formatting: Don't add any /, just the preferred name of the folder"
	echo -e "\n\t-IX <include_extension>"
	echo "Uses an specific extension for the header files. This allows for the usage of other file extensions like hpp"
	echo "Formating: You just need to name the extension"
	echo -e "\n\t-SX <source_extension>"
	echo "Uses an specific extension for the source files. This allows for the usage of other file extensions like: tpp, cc..."
	echo "Formating: You just need to name the extension"
	echo -e "\n\t--single"
	echo "Specifies that there will be a single cpp file. It is assumed that you will only have source file, so no header directory"
	echo "will be made. You can still use the -I, -IX parameters, but it will result useless."
	echo -e "\n\t--library=dynamic|static"
	echo "It will prepare the makefile for library making. You can use this option with any other, even --single."
	echo "Defaults to static library."
	echo -e "\n\t--force"
	echo "It will force the creation of the creation of the targets that couldn't be found in the given path, if that path doesn't exist then the targets will be missed still"
	echo -e "\nNotes:\n"
	echo ">The script doesn't care the order in which you use the parameters." 
	echo ">You might use -IS <include_dir> <source_dir> and -ISX <include_extension> <source_extension> instead of -I -S and -IX -SX."
	echo ">The path you use will define were your targets are, in other words, if /this/is/your/path/"
	echo "then, your targets will be interpreted as: /this/is/your/path/target1 /this/is/your/path/target2 ... /this/is/your/path/targetn."
	echo "Being target the directory where you will work."
	exit 0;
}
#Helps parse and verify the parameters, if any have been passed. 0 equals true, 1 equals false. FORMAT can be greater than one.
verification(){
	#Local variables used to catch parameters.
	local FINISHED=0
	local FORMAT=0
	local REPEATED=0

	#Let's see if the user wants some help, if thats the case, the program will show a guide.
	if [ "$#" == 0 ]
	then
		FORMAT=2
	elif [ "$1" == "--help" ] || [ "$1" == "-help" ] || [ "$1" == "-h" ]
	then
		guide
	fi

	#Here starts the loop.
	while [ $FORMAT -eq 0 ] && [ "$FINISHED" -eq 0 ]
	do
		#Saves the parameter before it is processed, that way, if the parameter is duplicated, then the script stops.
		for param in "${USED_PARAMS[@]}"; do
      if [ "$param" == "$1" ]; then
        REPEATED=1
        FORMAT=1
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
		#As a note, FORMAT will take the value 3 if there are no targets.
		case "$1" in
		-P|--path)
			if [ "$#" -le 2 ]
			then
				FORMAT=2
			elif [ ! -d "$2" ]
			then
				echo "Error. The given path doesn't exist."
				FORMAT=1
			else
				PATH_USED="$2"
				shift 2
				USED=$((USED+2))
			fi
		;;
		-S|--source)
			if [ "$#" -le 2 ]
			then
				FORMAT=2
			elif [ "$2" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				SOURCE="$2"
				shift 2
				USED=$((USED+2))
			fi
		;;
		-I|--include)
			if [ "$#" -le 2 ]
			then
				FORMAT=2
			elif [ "$2" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				INCLUDE="$2"
				shift 2
				USED=$((USED+2))
			fi
		;;
		-IS)
			if [ "$#" -le 3 ]
			then
				FORMAT=2
			elif [ "$2" == -* ] || [ "$3" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				INCLUDE="$2"
				SOURCE="$3"
				shift 3
				USED=$((USED+3))
			fi
		;;
		-IX)
			if [ "$#" -le 2 ]
			then
				FORMAT=2
			elif [ "$2" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				INCEXTENSION="$2"
				shift 2
				USED=$((USED+2))
			fi
		;;
		-SX)
			if [ "$#" -le 2 ]
			then
				FORMAT=2
			elif [ "$2" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				SRCEXTENSION="$2"
				shift 2
				USED=$((USED+2))
			fi
		;;
		-ISX)
			if [ "$#" -le 3 ]
			then
				FORMAT=2
			elif [ "$2" == -* ] || [ "$3" == -* ]
			then
				echo "Error. You didn't introduce the value of the parameter."
				FORMAT=1
			else
				INCEXTENSION="$2"
				SRCEXTENSION="$3"
				shift 3
				USED=$((USED+3))
			fi
		;;
		--single)
			if [ "$#" -le 1 ]
			then
				FORMAT=2
			else
				ONEFILE=1
				shift
				USED=$((USED+1))
			fi
		;;
		--library=dynamic)
			if [ "$#" -le 1 ]
			then
				FORMAT=2
			else	
				LIBRARY=1
				LIBRARYYPE="dynamic"
				shift 
				USED=$((USED+1))
			fi
		;;
		--library=static)
			if [ "$#" -le 1 ]
			then
				FORMAT=2
			else	
				LIBRARY=1
				LIBRARYTYPE="static"
				shift 
				USED=$((USED+1))
			fi
		;;
		--force)
			if [ "$#" -le 1 ]
			then
				FORMAT=2
			else
				FORCE=1
				shift
				USED=$((USED+1))
			fi
		;;
		-*|--*)
			echo "The given parameter $1 doesn't exist"
			FORMAT=1
		;;
		*)
			FINISHED=1
		;;
		esac
	done
	#Catches the error format and if any of the parameters have been repeated.
	if [ $REPEATED -eq 1 ]
	then
		echo "You have repeating parameters."
	fi
	if [ $FORMAT -eq 2 ]
	then
		echo "There are no targets to process."
	fi
	if [ $FORMAT -ge 1 ]
	then
		echo -e "Aborting..."
		echo "The format seems to be incorrect, for more help on the use -h, --help or -help"
		echo -e "Example of usage: ./NameOfTheProgram --force -P /example/path -S source mytarget1 mytarget2\n"
		exit 1;
	fi
	NUM_ARGS="$#"
}


#The function that makes de the Makefile
makefile_Maker(){
	#Header of the makefile
	echo "#@Brief: Basic makefile" > $MKE
	echo "#@Author: Javier Niño Sánchez" >> $MKE
	echo "#@Date: `date +%d/%m/%Y`" >> $MKE

	#Prints the flags for g++ and the working directories
	echo "" >> $MKE
	echo "#Options and directories" >> $MKE
	echo "CXXFLAGS = -std=c++17 -Wall -g -Ofast" >> $MKE

	echo "PROJECT_DIR = $PROJECT_DIR" >> $MKE
	echo "SRC_DIR = ./$SOURCE/" >> $MKE
	echo "HEADER_DIR = ./$INCLUDE/" >> $MKE
	echo "OBJ_DIR = ./objects/" >> $MKE
	echo "" >> $MKE

	#If you are making an executable, then it will print out the target only
	#If you are making a library, then it will have the .ar or the .so extension
	echo "#Globals" >> $MKE
	if [ $LIBRARY -eq 0 ]; then
		echo "NAME = $targets" >> $MKE
	elif [ "$LIBRARYTYPE" == "static" ]; then
		echo "NAME = $targets.ar" >> $MKE
	else
		echo "NAME = $targets.so" >> $MKE
	fi
	#Scans the source files and the header files. ONLY ONE EXECUTABLE CAN BE MADE WITH THE BASIC MAKEFILE
	echo 'SOURCES := $(wildcard $(SRC_DIR)*.'"$SRCEXTENSION)" >> $MKE
	
	if [ $ONEFILE -eq 0 ]; then
		echo 'HEADERS := $(wildcard $(HEADER_DIR)*.'"$INCEXTENSION)" >> $MKE
	fi
		
	echo 'OBJECTS := $(patsubst $(SRC_DIR)%.'"$SRCEXTENSION"', $(OBJ_DIR)%.o, $(SOURCES))' >> $MKE
	echo "" >> $MKE
	#Makes the directory where the objects will be stored and makes the executable/library
	echo 'all: obj $(NAME)' >> $MKE
	echo "#Make the directory for the objects" >> $MKE
	echo "obj:" >> $MKE
	echo -e '\t@mkdir -p $(OBJ_DIR)' >> $MKE
		
	if [ $ONEFILE -eq 0 ]; then
		if [ $LIBRARY -eq 0 ]; then
			echo "#Link it all together" >> $MKE
			echo '$(NAME): $(OBJECTS) $(HEADERS)' >> $MKE
			echo -e '\tg++ $(CXXFLAGS) $(OBJECTS) -o $(NAME)' >> $MKE
		elif [ "$LIBRARYTYPE" == "static" ]; then
			echo "#Make a static library" >> $MKE
			echo '$(NAME): $(OBJECTS) $(HEADERS)' >> $MKE
			echo -e '\tar rcs $(NAME).ar $(OBJECTS)' >> $MKE
		else
			echo "#Make a dynamic library" >> $MKE
			echo '$(NAME): $(OBJECTS) $(HEADERS)' >> $MKE
			echo -e '\tg++ -shared -o $(NAME).so $(OBJECTS)' >> $MKE
		fi

		echo "#Compile source code into objects" >> $MKE
		echo '$(OBJ_DIR)%.o: $(SRC_DIR)%.cpp $(HEADERS)' >> $MKE
		echo -e '\tg++ -c $(CXXFLAGS) -I$(HEADER_DIR) -o $@ $<' >> $MKE
	else
		if [ $LIBRARY -eq 0 ]; then
			echo "#Link the single file" >> $MKE
			echo '$(NAME): $(OBJECTS)' >> $MKE
			echo -e '\tg++ $(CXXFLAGS) $(OBJECTS) -o $(NAME)' >> $MKE
		elif [ "$LIBRARYTYPE" == "static" ]; then
			echo "#Make a static library" >> $MKE
			echo '$(NAME): $(OBJECTS)' >> $MKE
			echo -e '\tar rcs $(NAME).ar $(OBJECTS)' >> $MKE
		else
			echo "#Make a dynamic library" >> $MKE
			echo '$(NAME): $(OBJECTS)' >> $MKE
			echo -e '\tg++ -shared -o $(NAME).so $(OBJECTS)' >> $MKE
		fi
		echo "#Compile the single file into object" >> $MKE
		echo '$(OBJ_DIR)%.o: $(SRC_DIR)%.'"$SRCEXTENSION" >> $MKE
		echo -e '\tg++ -c $(CXXFLAGS) -o $@ $<' >> $MKE
	fi
	#auxiliar function
	echo "#Clean everything" >> $MKE
	echo "clean:" >> $MKE
	echo -e '\t@rm -rf $(OBJ_DIR) $(NAME)' >> $MKE
	echo ".PHONY: all clean" >> $MKE
}


verification $@
#shift the parameters according to its use in the verification function
for (( c=1; c<="$USED"; c++ ))
do
	shift
done
#process every target, updating or creating their respective makefiles
for targets in $@
do
	#each target will be treated as an independet project
	PROJECT_DIR="$PATH_USED/$targets"
	#if the path above exists, then it will starts making the makefile, otherwise, it will be marked as missed if the parameter --force was not specified
	if [ ! -d "$PROJECT_DIR" ] && [ $FORCE -eq 1 ]
	then
		mkdir "$PROJECT_DIR"
		CREATED=$((CREATED+1))
		echo "CREATED: $PROJECT_DIR"
	fi
	if [ -d "$PROJECT_DIR" ]
		then
		MKE="$PROJECT_DIR/Makefile"
		if [ "$PROJECT_DIR" == "." ]
		then
			PROJECT_DIR=$(pwd)
		fi
		#if the project already had a Makefile, then it will be marked as updated and the original makefile will be overwritten
		if [ -f "$MKE" ]
		then
			UPDATED=$((UPDATED+1))
			echo "UPDATED: $PROJECT_DIR"
		else
		#creation of the Makefile if the project didn't have one, in that case, the target will be marked as completed (if everything goes accordingly)
			touch $MKE
			if [ $? -eq 0 ]
			then
				COMPLETED=$((COMPLETED+1))
				echo "COMPLETED: $PROJECT_DIR"
			else
				MISSED=$((MISSED+1))
				echo "MISSED: $PROJECT_DIR"
			fi
		fi
		#checks if the proposed source and header directories exist, otherwise, they are created
		if [ ! -d "$PROJECT_DIR/$SOURCE" ]
		then
			mkdir "$PROJECT_DIR/$SOURCE"
			echo "Source directory created"
		fi
		if [ ! -d "$PROJECT_DIR/$INCLUDE" ] && [ $ONEFILE -eq 0 ]
		then
			mkdir "$PROJECT_DIR/$INCLUDE"
			echo "Include directory created"
		fi
		#starts writing the makefile, following the parameters given (HAS TO BE UPTDATED TO SUPPORT THE MOST RECENT ADDITIONS)
		makefile_Maker
	elif [ $FORCE -eq 0 ]
	then
	#as said before, if the path couldn't be found and the --force option wasn't specified, then, the target will be considered missed
		MISSED=$((MISSED+1))
		echo "MISSED: $PROJECT_DIR"
	fi
	#keep track of the progress
	PROGRESS=$(( PROGRESS + 100/NUM_ARGS ))
	echo "Progress: $PROGRESS%"
done
if [ $FORCE -eq 0 ]
then
	echo -e "UPDATED=$UPDATED\tCOMPLETED=$COMPLETED\tMISSED=$MISSED"
else
	echo -e "UPDATED=$UPDATED\tCOMPLETED=$COMPLETED\tCREATED=$CREATED"
fi
#c'est finni!
exit 0
