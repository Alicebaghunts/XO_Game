NAME = xo

CXX = clang++
CXXFLAGS = -Wall -Wextra -Werror -std=c++98 -ObjC++ -fobjc-arc

FRAMEWORKS = -framework Cocoa -framework AppKit -framework QuartzCore

SRCS = main.mm
OBJS = $(SRCS:.mm=.o)

all: $(NAME)

%.o: %.mm
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) $(FRAMEWORKS) -o $(NAME)

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all clean fclean re
