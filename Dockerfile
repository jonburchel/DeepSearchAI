# Stage 1: Build frontend
FROM node:20 AS frontend-builder

WORKDIR /code/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend ./
RUN npm run build

# Stage 2: Build backend
FROM python:3.11 AS backend-builder

WORKDIR /code

# Copy the backend of the application code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the built frontend from the previous stage
COPY --from=frontend-builder /code/frontend/dist ./static

# Copy the rest of the application code
COPY . .

# Stage 3: Production
FROM python:3.11-slim AS production

WORKDIR /code

# Copy the necessary files and directories from the backend-builder stage
COPY --from=backend-builder /code/static ./static
COPY --from=backend-builder /code/backend ./backend
COPY --from=backend-builder /code/app.py ./app.py
COPY --from=backend-builder /code/gunicorn.conf.py ./gunicorn.conf.py
COPY --from=backend-builder /code/requirements.txt ./requirements.txt

# Install the necessary Python packages
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 50505

CMD ["gunicorn", "-c", "gunicorn.conf.py", "app:app", "--bind", "0.0.0.0:50505", "--reload"]