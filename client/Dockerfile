FROM node:18

WORKDIR /app

# Copy package.json files
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose port for development server
EXPOSE 5173

# Start the development server
CMD ["npm", "run", "dev"]