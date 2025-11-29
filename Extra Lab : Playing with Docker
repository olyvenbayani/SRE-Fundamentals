# Extra Lab: Introduction to Containers

This lab provides a hands-on introduction to Docker for beginners. You'll learn how to run pre-built containers, build your own custom image, and perform basic management tasks. This version is designed to run in your local terminal or VS Code's integrated terminal, assuming you have Docker installed on your machine. We've expanded the lab to include more detailed guidance on building Dockerfiles, including best practices and a multi-stage build example. Additionally, we've added exercises to help you appreciate the power of containerization by experiencing its benefits firsthand—such as running isolated environments without conflicts on your host machine.

## Prerequisites
- Install Docker on your local machine:
  - For Windows/Mac: Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/) from the official website. Follow the installation wizard and ensure Docker is running (check with `docker --version` in your terminal).
  - For Linux: Follow the official [installation guide](https://docs.docker.com/engine/install/) for your distribution (e.g., `sudo apt install docker.io` on Ubuntu, then start the service with `sudo systemctl start docker`).
- A terminal (e.g., Command Prompt/PowerShell on Windows, Terminal on Mac/Linux) or VS Code with its terminal open (Ctrl+` or Cmd+`).
- Basic familiarity with command-line navigation.

Open your terminal or VS Code terminal and proceed.

## 1. Verify Docker Installation
1-a. In your terminal, run:  
```bash
docker --version
```  
This should output something like "Docker version 27.0.3, build 7d4bcd8". If not, ensure Docker is installed and running.

1-b. Test with a simple command:  
```bash
docker run hello-world
```  
This downloads and runs a test container. You should see a message confirming Docker works.

## 2. Run Your First Container: Hello World
2-a. Execute the following command:  
```bash
docker run hello-world
```  
This pulls the `hello-world` image from Docker Hub and runs it. The output explains how containers work. Notice how this runs instantly without installing anything extra on your machine—this is your first taste of container portability.

## 3. Run a Web Application Container
Now, let's run an interactive container hosting a simple web app.

3-a. Execute:  
```bash
docker run -d -p 8080:80 --name getting-started docker/getting-started
```  
This pulls the `docker/getting-started` image, runs it in detached mode (`-d`), names the container (`--name`), and maps port 80 inside the container to port 8080 on your host (`-p 8080:80`). Use 8080 to avoid conflicts with system ports.

3-b. Open your web browser and navigate to `http://localhost:8080`. You should see Docker's getting-started tutorial page.

3-c. To list running containers:  
```bash
docker ps
```  
Note the container ID or name (e.g., "getting-started") for later use.

3-d. To stop the container:  
```bash
docker stop getting-started
```

## 4. Build and Run a Custom Image
Let's create a simple Python application, build a Docker image for it, and run it. This section introduces the basics of building a Dockerfile.

4-a. Create a working directory:  
```bash
mkdir docker-lab && cd docker-lab
```

4-b. Create a simple Python script using echo (or edit in VS Code). We'll add a dependency to demonstrate how containers handle packages without affecting your host:  
```bash
echo -e 'import numpy as np\nprint("Hello from my custom Docker container!")\nprint("Numpy version:", np.__version__)' > app.py
```

4-c. Create a `Dockerfile` (use echo or edit in VS Code). A Dockerfile is a text file that contains instructions for building a Docker image:  
```bash
echo -e 'FROM python:3.9-slim\nRUN pip install numpy\nCOPY app.py .\nCMD ["python", "app.py"]' > Dockerfile
```  
- `FROM`: Specifies the base image (here, a slim Python 3.9 environment).  
- `RUN`: Executes commands during the build (here, installing numpy via pip).  
- `COPY`: Copies files from your host into the image (here, `app.py` to the working directory).  
- `CMD`: Defines the default command to run when the container starts.

4-d. Build the image:  
```bash
docker build -t my-python-app .
```  
The `-t` flag tags the image with a name (`my-python-app`). The `.` tells Docker to use the current directory for the build context. Observe how Docker installs numpy inside the image—no changes to your local Python setup.

4-e. Run your custom container:  
```bash
docker run my-python-app
```  
You should see the output: "Hello from my custom Docker container!" followed by the numpy version. This runs even if you don't have Python or numpy installed locally, showcasing isolation and consistency.

## 5. Advanced Dockerfile Building: Best Practices and Multi-Stage Builds
Now that you've built a basic image, let's dive deeper into Dockerfile creation. We'll cover best practices and build a more complex example using a multi-stage build to optimize image size.

### Best Practices for Dockerfiles
- **Use official base images**: Start with trusted images from Docker Hub (e.g., `python:3.9-slim` for smaller sizes).
- **Minimize layers**: Each instruction (e.g., `RUN`, `COPY`) creates a layer. Combine commands where possible (e.g., chain `apt-get update && apt-get install`).
- **Leverage caching**: Order instructions from least to most frequently changing (e.g., copy dependencies before application code).
- **Keep images small**: Use slim or alpine variants, clean up after installations (e.g., remove cache).
- **Security**: Run as non-root user with `USER`, avoid unnecessary packages.
- **Multi-stage builds**: Use for compiling code and copying artifacts to a runtime image, reducing final size.
- **Environment variables**: Use `ENV` for configurable values.
- **Entrypoint vs. CMD**: Use `ENTRYPOINT` for fixed commands, `CMD` for defaults that can be overridden.

5-a. Create a new directory for this example:  
```bash
cd .. && mkdir advanced-docker && cd advanced-docker
```

5-b. Create a simple Node.js app (or use echo/VS Code):  
```bash
echo -e 'const http = require("http");\nconst server = http.createServer((req, res) => {\n  res.end("Hello from my Node.js app!");\n});\nserver.listen(3000, () => {\n  console.log("Server running on port 3000");\n});' > app.js
```

5-c. Create a `package.json` for dependencies:  
```bash
echo -e '{\n  "name": "node-app",\n  "version": "1.0.0",\n  "main": "app.js",\n  "dependencies": {}\n}' > package.json
```

5-d. Create an advanced `Dockerfile` using multi-stage build:  
```bash
echo -e '# Stage 1: Build stage\nFROM node:20 AS builder\nWORKDIR /app\nCOPY package.json .\nRUN npm install\nCOPY app.js .\n\n# Stage 2: Runtime stage\nFROM node:20-slim\nWORKDIR /app\nCOPY --from=builder /app .\nEXPOSE 3000\nCMD ["node", "app.js"]' > Dockerfile
```  
- This uses two stages: One for building (installing dependencies), and a slim runtime stage to keep the final image small.  
- `WORKDIR`: Sets the working directory inside the container.  
- `EXPOSE`: Documents the port the app uses (doesn't actually publish it).  
- `--from=builder`: Copies files from the first stage.

5-e. Build the multi-stage image:  
```bash
docker build -t my-node-app .
```

5-f. Run the container with port mapping:  
```bash
docker run -d -p 3000:3000 --name node-app my-node-app
```

5-g. Test it: Open `http://localhost:3000` in your browser. You should see "Hello from my Node.js app!".  

5-h. Stop the container:  
```bash
docker stop node-app
```

5-i. Compare image sizes (optional):  
```bash
docker images | grep my-node-app
```  
Notice how multi-stage keeps it lean compared to a single-stage build with unnecessary build tools. This demonstrates efficiency in real-world scenarios.
