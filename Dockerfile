FROM node:alpine

# ============================================================
# FRONTEND
# ============================================================

WORKDIR /app/client

# Copy dependency files first for Docker layer caching
COPY client/package.json client/package-lock.json ./

# Install frontend dependencies
RUN npm install

# Copy frontend source code
COPY client/ .

# Build frontend
RUN npm run build


# ============================================================
# BACKEND
# ============================================================

WORKDIR /app/server

# Copy dependency files first for Docker layer caching
COPY server/package.json server/package-lock.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy backend source code
COPY server/ .


# ============================================================
# COPY FRONTEND BUILD INTO BACKEND
# ============================================================

RUN mkdir -p public

RUN cp -r /app/client/public/* public/


# ============================================================
# PRODUCTION CONFIGURATION
# ============================================================

ENV NODE_ENV=production


# ============================================================
# SECURITY — RUN AS NON-ROOT USER
# ============================================================

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

RUN chown -R appuser:appgroup /app

USER appuser


# ============================================================
# APPLICATION
# ============================================================

EXPOSE 5000

CMD ["npm", "start"]